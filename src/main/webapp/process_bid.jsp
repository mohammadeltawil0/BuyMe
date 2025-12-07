<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" import="com.cs336.pkg.*, java.sql.*, java.util.*" %>
<%
    // This is the core script for processing all bid types (manual and auto-limit setting).
    
    // --- 1. Authentication and Input Retrieval ---
    Integer bidderId = (Integer) session.getAttribute("user_id");
    
    // Auth Guard: Must be logged in
    if (bidderId == null) {
        response.sendRedirect("index.jsp");
        return;
    }

    String auctionIdStr = request.getParameter("auction_id");
    String bidType = request.getParameter("bid_type"); // "manual" or "auto"
    String bidAmountStr = request.getParameter("bid_amount"); // for manual
    String maxLimitStr = request.getParameter("max_limit");   // for auto
    String itemName = ""; // To store item name for the alert message

    if (auctionIdStr == null || auctionIdStr.isEmpty()) {
        response.sendRedirect("browse.jsp");
        return;
    }
    int auctionId = Integer.parseInt(auctionIdStr);
    String redirectUrl = "auction_detail.jsp?id=" + auctionIdStr;

    ApplicationDB db = new ApplicationDB();
    Connection con = db.getConnection();
    
    PreparedStatement ps = null;
    ResultSet rs = null;

    try {
        con.setAutoCommit(false); // Start Transaction

        // --- 2. Fetch Current Auction State ---
        // We need: Increment, Seller, Current Highest Bidder, Current Max Bid, AND Item Name
        String sqlState = "SELECT item_name, seller_id, increment, close_time, is_removed, a.init_price, " +
                          "(SELECT bid_amount FROM Bid_History WHERE auction_id = a.auction_id ORDER BY bid_amount DESC LIMIT 1) as current_price, " +
                          "(SELECT user_id FROM Bid_History WHERE auction_id = a.auction_id ORDER BY bid_amount DESC LIMIT 1) as current_winner_id " +
                          "FROM Auction a WHERE a.auction_id = ?";
        
        ps = con.prepareStatement(sqlState);
        ps.setInt(1, auctionId);
        rs = ps.executeQuery();

        float increment = 0;
        float currentPrice = 0;
        float initPrice = 0;
        int currentWinnerId = -1;
        int sellerId = -1;
        Timestamp closeTime = null;
        boolean isRemoved = true;

        if (rs.next()) {
            itemName = rs.getString("item_name"); // Get item name for alert
            increment = rs.getFloat("increment");
            sellerId = rs.getInt("seller_id");
            closeTime = rs.getTimestamp("close_time");
            initPrice = rs.getFloat("a.init_price");
            isRemoved = rs.getBoolean("is_removed");
            
            // Determine current price and winner
            float dbCurrentPrice = rs.getFloat("current_price");
            if (rs.wasNull() || dbCurrentPrice == 0) {
                currentPrice = initPrice;
                currentWinnerId = -1; // No winner yet
            } else {
                currentPrice = dbCurrentPrice;
                currentWinnerId = rs.getInt("current_winner_id");
            }
        } else {
            throw new Exception("Auction not found.");
        }

        // --- 3. Basic Validation ---
        if (isRemoved) throw new Exception("Auction removed.");
        if (System.currentTimeMillis() > closeTime.getTime()) throw new Exception("Auction closed.");
        if (bidderId == sellerId) throw new Exception("Seller cannot bid.");

        // --- 4. Process User Action (Challenger Setup) ---
        float challengerLimit = 0;
        boolean isManualBid = false;

        if ("manual".equals(bidType)) {
            if (bidAmountStr == null) throw new Exception("Missing bid amount.");
            float manualBid = Float.parseFloat(bidAmountStr);
            
            // Validate Manual Bid Minimum
            float minReq = (currentWinnerId == -1) ? initPrice : (currentPrice + increment);
            // Use epsilon for float comparison
            if (manualBid < minReq - 0.001) throw new Exception("Bid too low. Min: " + String.format("%.2f", minReq));
            
            challengerLimit = manualBid;
            isManualBid = true;
            
        } else if ("auto".equals(bidType)) {
            if (maxLimitStr == null) throw new Exception("Missing max limit.");
            float autoLimit = Float.parseFloat(maxLimitStr);
            
            float minLimitReq = (currentWinnerId == -1) ? initPrice : currentPrice;
            if (autoLimit <= minLimitReq) throw new Exception("Limit must be > " + String.format("%.2f", minLimitReq));
            
            // Save/Update Auto Limit in DB
            String sqlAuto = "INSERT INTO Auto_Bid (user_id, auction_id, max_limit) VALUES (?, ?, ?) " +
                             "ON DUPLICATE KEY UPDATE max_limit = VALUES(max_limit)";
            try (PreparedStatement psAuto = con.prepareStatement(sqlAuto)) {
                psAuto.setInt(1, bidderId);
                psAuto.setInt(2, auctionId);
                psAuto.setFloat(3, autoLimit);
                psAuto.executeUpdate();
            }
            
            challengerLimit = autoLimit;
        }

        // --- 5. The Duel Engine ---
        
        // Fetch Defender Limit
        float defenderLimit = 0;
        if (currentWinnerId != -1) {
            String sqlDef = "SELECT max_limit FROM Auto_Bid WHERE auction_id = ? AND user_id = ?";
            try (PreparedStatement psDef = con.prepareStatement(sqlDef)) {
                psDef.setInt(1, auctionId);
                psDef.setInt(2, currentWinnerId);
                try (ResultSet rsDef = psDef.executeQuery()) {
                    if (rsDef.next()) {
                        defenderLimit = rsDef.getFloat("max_limit");
                    }
                }
            }
        }
        
        // Just updating own limit?
        if (bidderId == currentWinnerId) {
            con.commit();
            response.sendRedirect(redirectUrl + "&auto_success=1");
            return;
        }
        
        // --- DUEL LOGIC START ---
        
        int finalWinnerId = currentWinnerId;
        float finalPrice = currentPrice; // To be calculated
        
        // Scenario A: Challenger Wins
        if (challengerLimit > defenderLimit) {
            finalWinnerId = bidderId;
            
            float effectiveDefenderMax = (defenderLimit > 0) ? defenderLimit : currentPrice;

            // First bid special case
            if (currentWinnerId == -1) {
                finalPrice = isManualBid ? challengerLimit : initPrice;
            } else {
                finalPrice = effectiveDefenderMax + increment;
                if (isManualBid) {
                     finalPrice = challengerLimit; 
                } else {
                     if (finalPrice > challengerLimit) finalPrice = challengerLimit;
                }
            }
            
            // Insert ONLY the Winner's bid (Challenger)
            if (finalPrice > currentPrice || currentWinnerId == -1) {
                String sqlInsert = "INSERT INTO Bid_History (auction_id, user_id, bid_amount, bid_time) VALUES (?, ?, ?, NOW())";
                try (PreparedStatement psIns = con.prepareStatement(sqlInsert)) {
                    psIns.setInt(1, auctionId);
                    psIns.setInt(2, finalWinnerId);
                    psIns.setFloat(3, finalPrice);
                    psIns.executeUpdate();
                }
            }

        } else {
            // Scenario B: Defender Wins (Auto-Defense)
            finalWinnerId = currentWinnerId;
            
            // New price is Challenger's Max + Increment
            float newDefenderPrice = challengerLimit + increment;
            if (newDefenderPrice > defenderLimit) newDefenderPrice = defenderLimit;
            
            finalPrice = newDefenderPrice; // For alert message context
            
            // 1. Insert Challenger's Bid (The "Losing" Bid)
            String sqlInsert1 = "INSERT INTO Bid_History (auction_id, user_id, bid_amount, bid_time) VALUES (?, ?, ?, NOW())";
            try (PreparedStatement psIns = con.prepareStatement(sqlInsert1)) {
                psIns.setInt(1, auctionId);
                psIns.setInt(2, bidderId);
                psIns.setFloat(3, challengerLimit);
                psIns.executeUpdate();
            }
            
            // 2. Insert Defender's Counter-Bid (The "Winning" Bid)
            if (newDefenderPrice > challengerLimit) {
                String sqlInsert2 = "INSERT INTO Bid_History (auction_id, user_id, bid_amount, bid_time) VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 1 SECOND))";
                try (PreparedStatement psIns = con.prepareStatement(sqlInsert2)) {
                    psIns.setInt(1, auctionId);
                    psIns.setInt(2, finalWinnerId); // Defender
                    psIns.setFloat(3, newDefenderPrice);
                    psIns.executeUpdate();
                }
            }
        }
        
        // --- 6. ALERT LOGIC (UPDATED for new Schema) ---
        // Trigger: The winner has changed (and there was a previous winner)
        if (currentWinnerId != -1 && finalWinnerId != currentWinnerId) {
            // The old winner (currentWinnerId) has lost.
            
            // Message body for the alert
            String messageBody = "You have been outbid on item '" + itemName + "'. The current price is now $" + String.format("%.2f", finalPrice) + ".";

            // Use the new columns: message_type, auction_id, message_body
            String sqlAlert = "INSERT INTO Inbox (user_id, message_type, auction_id, message_body) VALUES (?, 'OUTBID', ?, ?)";
            
            try (PreparedStatement psAlert = con.prepareStatement(sqlAlert)) {
                psAlert.setInt(1, currentWinnerId); // Target: The OLD winner
                psAlert.setInt(2, auctionId);       // Link to the auction
                psAlert.setString(3, messageBody);  // The message content
                psAlert.executeUpdate();
            }
        }
        
        con.commit();
        
        // Redirect based on outcome
        if (finalWinnerId == bidderId) {
             if (isManualBid) response.sendRedirect(redirectUrl + "&manual_success=1");
             else response.sendRedirect(redirectUrl + "&auto_success=1");
        } else {
             response.sendRedirect(redirectUrl + "&bid_error=outbid_immediately"); 
        }

    } catch (Exception e) {
        if (con != null) try { con.rollback(); } catch (SQLException ex) {}
        String msg = "bid_error=general";
        if (e.getMessage() != null && e.getMessage().contains("too low")) msg = "bid_error=too_low";
        response.sendRedirect(redirectUrl + "&" + msg);
    } finally {
        if (rs != null) try { rs.close(); } catch (SQLException e) {}
        if (ps != null) try { ps.close(); } catch (SQLException e) {}
        if (con != null) {
            try { con.setAutoCommit(true); } catch (SQLException e) {}
            db.closeConnection(con);
        }
    }
%>