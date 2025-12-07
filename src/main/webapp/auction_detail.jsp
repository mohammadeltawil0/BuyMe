<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" import="com.cs336.pkg.*, java.sql.*, java.util.*" %>
<%
    // Auth Guard: User must be logged in to view auction details and bid.
    Integer userId = (Integer) session.getAttribute("user_id");
    if (userId == null) {
        response.sendRedirect("index.jsp");
        return;
    }
    
    // --- 1. Get Auction ID from URL ---
    String auctionIdStr = request.getParameter("id");
    if (auctionIdStr == null || auctionIdStr.isEmpty()) {
        response.sendRedirect("browse.jsp"); // If no ID, redirect back
        return;
    }
    int auctionId = Integer.parseInt(auctionIdStr);
    
    // --- 2. Database Initialization ---
    ApplicationDB db = new ApplicationDB();
    Connection con = db.getConnection();
    
    // Data containers
    Map<String, String> auctionDetails = new HashMap<>();
    List<Map<String, String>> itemFields = new ArrayList<>();
    List<Map<String, String>> bidHistory = new ArrayList<>();
    float currentHighBid = 0.00f; // Determined by query
    float minimumNextBid = 0.00f; // Calculated dynamically
    int currentWinnerId = -1;
    int sellerId = -1;
    
    // PreparedStatement objects
    PreparedStatement psDetails = null;
    PreparedStatement psFields = null;
    PreparedStatement psHistory = null;
    PreparedStatement psCurrentBid = null;
    PreparedStatement psAutoBid = null;
    PreparedStatement psCheckAlert = null;
    PreparedStatement psInsertAlert = null;
    ResultSet rs = null;

    try {
        // --- 3. FETCH: Auction Main Details (Auction, SubCategory, Current Bid, Winner) ---
        String sqlDetails = "SELECT a.*, s.name AS subcat_name, c.name AS cat_name, " +
                            "u.username AS seller_username, " +
                            "(SELECT bid_amount FROM Bid_History b WHERE b.auction_id = a.auction_id ORDER BY bid_amount DESC LIMIT 1) AS current_bid, " +
                            "(SELECT user_id FROM Bid_History b WHERE b.auction_id = a.auction_id ORDER BY bid_amount DESC LIMIT 1) AS winner_id " +
                            "FROM Auction a " +
                            "JOIN SubCategory s ON a.subcat_id = s.subcat_id " +
                            "JOIN Category c ON s.cat_id = c.cat_id " +
                            "JOIN User u ON a.seller_id = u.user_id " +
                            "WHERE a.auction_id = ?";
        psDetails = con.prepareStatement(sqlDetails);
        psDetails.setInt(1, auctionId);
        rs = psDetails.executeQuery();

        if (rs.next()) {
            String itemName = rs.getString("item_name");
            sellerId = rs.getInt("seller_id"); // Get seller ID for alerts
            
            auctionDetails.put("item_name", itemName);
            auctionDetails.put("description", rs.getString("description"));
            auctionDetails.put("close_time", rs.getString("close_time"));
            auctionDetails.put("init_price", String.format("%.2f", rs.getFloat("init_price")));
            auctionDetails.put("min_price", String.format("%.2f", rs.getFloat("min_price")));
            auctionDetails.put("increment", String.format("%.2f", rs.getFloat("increment")));
            auctionDetails.put("subcat_name", rs.getString("subcat_name"));
            auctionDetails.put("cat_name", rs.getString("cat_name"));
            auctionDetails.put("seller_username", rs.getString("seller_username"));
            
            currentHighBid = rs.getFloat("current_bid");
            currentWinnerId = rs.getInt("winner_id"); 
            if (rs.wasNull()) currentWinnerId = -1;

            float increment = rs.getFloat("increment");
            float initPrice = rs.getFloat("init_price");
            float minPrice = rs.getFloat("min_price");
            
            // Determine the price and the minimum next bid required
            if (currentHighBid > 0) {
                minimumNextBid = currentHighBid + increment;
                auctionDetails.put("current_price", String.format("%.2f", currentHighBid));
                auctionDetails.put("next_bid", String.format("%.2f", minimumNextBid));
            } else {
                minimumNextBid = initPrice; 
                auctionDetails.put("current_price", String.format("%.2f", initPrice));
                auctionDetails.put("next_bid", String.format("%.2f", minimumNextBid));
            }

            // Check if auction is closed or removed
            Timestamp closeTime = rs.getTimestamp("close_time");
            boolean isRemoved = rs.getBoolean("is_removed");
            long currentTime = System.currentTimeMillis();
            
            if (isRemoved) {
                auctionDetails.put("status", "REMOVED");
            } else if (currentTime > closeTime.getTime()) {
                // --- CLOSED LOGIC ---
                boolean isSold = (currentHighBid >= minPrice && currentWinnerId != -1);
                
                if (isSold) {
                    auctionDetails.put("status", "CLOSED - SOLD");
                    
                    // 1. Alert Winner ('AUCTION_WON')
                    if (currentWinnerId != -1) {
                        String checkSql = "SELECT inbox_id FROM Inbox WHERE user_id = ? AND auction_id = ? AND message_type = 'SYSTEM'";
                        psCheckAlert = con.prepareStatement(checkSql);
                        psCheckAlert.setInt(1, currentWinnerId);
                        psCheckAlert.setInt(2, auctionId);
                        ResultSet rsAlert = psCheckAlert.executeQuery();

                        if (!rsAlert.next()) {
                            String winMsg = "Congratulations! You won the auction for '" + itemName +
                                    "' with a bid of $" + String.format("%.2f", currentHighBid) + ".";
                            String insertSql = "INSERT INTO Inbox (user_id, message_type, auction_id, message_body) " +
                                    "VALUES (?, 'SYSTEM', ?, ?)";
                            psInsertAlert = con.prepareStatement(insertSql);
                            psInsertAlert.setInt(1, currentWinnerId);
                            psInsertAlert.setInt(2, auctionId);
                            psInsertAlert.setString(3, winMsg);
                            psInsertAlert.executeUpdate();
                        }
                        if (rsAlert != null) rsAlert.close();
                        if (psCheckAlert != null) psCheckAlert.close();
                    }

                    // Notify seller (sold)
                    String checkSellerSql = "SELECT inbox_id FROM Inbox WHERE user_id = ? AND auction_id = ? AND message_type = 'SYSTEM'";
                    psCheckAlert = con.prepareStatement(checkSellerSql);
                    psCheckAlert.setInt(1, sellerId);
                    psCheckAlert.setInt(2, auctionId);
                    ResultSet rsSellerAlert = psCheckAlert.executeQuery();

                    if (!rsSellerAlert.next()) {
                        String soldMsg = "Your item '" + itemName + "' has been SOLD for $" +
                                String.format("%.2f", currentHighBid) + "!";
                        String insertSql = "INSERT INTO Inbox (user_id, message_type, auction_id, message_body) " +
                                "VALUES (?, 'SYSTEM', ?, ?)";
                        psInsertAlert = con.prepareStatement(insertSql);
                        psInsertAlert.setInt(1, sellerId);
                        psInsertAlert.setInt(2, auctionId);
                        psInsertAlert.setString(3, soldMsg);
                        psInsertAlert.executeUpdate();
                    }

                    if (rsSellerAlert != null) rsSellerAlert.close();
                    if (psCheckAlert != null) psCheckAlert.close();

                } else {
                    auctionDetails.put("status", "CLOSED - UNSOLD (Reserve Not Met)");

                    // Notify seller (unsold)
                    String checkSellerSql = "SELECT inbox_id FROM Inbox WHERE user_id = ? AND auction_id = ? AND message_type = 'SYSTEM'";
                    psCheckAlert = con.prepareStatement(checkSellerSql);
                    psCheckAlert.setInt(1, sellerId);
                    psCheckAlert.setInt(2, auctionId);
                    ResultSet rsSellerAlert = psCheckAlert.executeQuery();

                    if (!rsSellerAlert.next()) {
                        String unsoldMsg = "Your item '" + itemName + "' closed UNSOLD (reserve not met or no bids).";
                        String insertSql = "INSERT INTO Inbox (user_id, message_type, auction_id, message_body) " +
                                "VALUES (?, 'SYSTEM', ?, ?)";
                        psInsertAlert = con.prepareStatement(insertSql);
                        psInsertAlert.setInt(1, sellerId);
                        psInsertAlert.setInt(2, auctionId);
                        psInsertAlert.setString(3, unsoldMsg);
                        psInsertAlert.executeUpdate();
                    }

                    if (rsSellerAlert != null) rsSellerAlert.close();
                    if (psCheckAlert != null) psCheckAlert.close();
                }

            } else {
                auctionDetails.put("status", "OPEN");
            }
            
        } else {
            response.sendRedirect("browse.jsp"); // Auction not found
            return;
        }
        
        // --- 4. FETCH: Item-Specific Fields (Auction_Field) ---
        String sqlFields = "SELECT f.field_name, af.field_value " +
                           "FROM Auction_Field af JOIN Field f ON af.field_id = f.field_id " +
                           "WHERE af.auction_id = ?";
        psFields = con.prepareStatement(sqlFields);
        psFields.setInt(1, auctionId);
        rs = psFields.executeQuery();
        
        while (rs.next()) {
            Map<String, String> field = new HashMap<>();
            field.put("name", rs.getString("field_name"));
            field.put("value", rs.getString("field_value"));
            itemFields.add(field);
        }

        // --- 5. FETCH: Bid History (Bid_History) ---
        String sqlHistory = "SELECT b.bid_amount, b.bid_time, u.username " +
                            "FROM Bid_History b JOIN User u ON b.user_id = u.user_id " +
                            "WHERE b.auction_id = ? " +
                            "ORDER BY b.bid_time DESC";
        psHistory = con.prepareStatement(sqlHistory);
        psHistory.setInt(1, auctionId);
        rs = psHistory.executeQuery();
        
        while (rs.next()) {
            Map<String, String> bid = new HashMap<>();
            bid.put("amount", String.format("%.2f", rs.getFloat("bid_amount")));
            bid.put("time", rs.getString("bid_time"));
            bid.put("username", rs.getString("username"));
            bidHistory.add(bid);
        }
        
        // --- 6. FETCH: User's Max Limit (Auto_Bid) ---
        // This is necessary for the auto-bid form to show the current setting.
        float userMaxLimit = 0.00f;
        String sqlAutoBid = "SELECT max_limit FROM Auto_Bid WHERE auction_id = ? AND user_id = ?";
        psAutoBid = con.prepareStatement(sqlAutoBid);
        psAutoBid.setInt(1, auctionId);
        psAutoBid.setInt(2, userId);
        rs = psAutoBid.executeQuery();
        
        if (rs.next()) {
             userMaxLimit = rs.getFloat("max_limit");
        }
        auctionDetails.put("user_max_limit", String.format("%.2f", userMaxLimit));
        

    } catch (Exception e) {
        out.println("Error loading auction details: " + e.getMessage());
        return;
    } finally {
        // --- 7. Close resources ---
        if (rs != null) rs.close();
        if (psDetails != null) psDetails.close();
        if (psFields != null) psFields.close();
        if (psHistory != null) psHistory.close();
        if (psCurrentBid != null) psCurrentBid.close();
        if (psAutoBid != null) psAutoBid.close();
        if (psCheckAlert != null) psCheckAlert.close();
        if (psInsertAlert != null) psInsertAlert.close();
        if (con != null) db.closeConnection(con);
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title><%= auctionDetails.get("item_name") %> - Auction Detail</title>
    <style>
        .status-open { color: green; font-weight: bold; }
        .status-closed { color: darkred; font-weight: bold; }
        .status-removed { color: gray; font-style: italic; }
        .bid-area { border: 1px solid #ccc; padding: 15px; margin-bottom: 20px; border-radius: 5px; }
        /* Error Message Styles */
        .error-msg { color: red; font-weight: bold; background-color: #ffe6e6; padding: 10px; border: 1px solid red; margin-bottom: 10px;}
        .success-msg { color: green; font-weight: bold; background-color: #e6ffe6; padding: 10px; border: 1px solid green; margin-bottom: 10px;}
    </style>
</head>
<body>
    <a href="browse.jsp">← Back to Browse</a>
    <hr>
    
    <!-- *** ADDED: Error/Success Message Display *** -->
    <% 
        String bidError = request.getParameter("bid_error");
        if (bidError != null) {
            String msgText = "Error processing bid.";
            if (bidError.equals("too_low")) msgText = "Error: Your bid was too low. Please check the minimum next bid.";
            else if (bidError.equals("invalid_input")) msgText = "Error: Invalid input amount.";
            else if (bidError.equals("general")) msgText = "Error: Operation failed. Please try again.";
            else if (bidError.equals("outbid_immediately")) msgText = "Your bid was placed, but you were immediately outbid by an automatic bidder.";
            out.println("<div class='error-msg'>" + msgText + "</div>");
        }
        
        if (request.getParameter("manual_success") != null) {
            out.println("<div class='success-msg'>Success: Your bid has been placed!</div>");
        }
        if (request.getParameter("auto_success") != null) {
            out.println("<div class='success-msg'>Success: Your auto-bid limit has been set!</div>");
        }
    %>
    
    <h1><%= auctionDetails.get("item_name") %></h1>
    
    <!-- Status and Current Price Section -->
    <p><strong>Category:</strong> <%= auctionDetails.get("cat_name") %> > <%= auctionDetails.get("subcat_name") %></p>
    <p>
        <strong>Status:</strong> 
        <% 
            String status = auctionDetails.get("status");
            if (status.startsWith("OPEN")) {
                out.println("<span class='status-open'>" + status + "</span>");
            } else {
                out.println("<span class='status-closed'>" + status + "</span>");
            }
        %>
    </p>
    <% if (status.equals("OPEN")) { %>
        <p><strong>Closes:</strong> <%= auctionDetails.get("close_time") %></p>
    <% } %>
    <p>
        <strong>Seller:</strong>
        <a href="my_listings_public.jsp?user_id=<%= sellerId %>">
            <%= auctionDetails.get("seller_username") %>
        </a>

    </p>
    <p>
        <a href="similar_items.jsp?id=<%= auctionId %>">
            View Similar Items (Last 30 Days)
        </a>
    </p>
    <p>
        <a href="browse_questions.jsp?id=<%= auctionId %>">
            View Customer Q&A
        </a>
    </p>
    <hr>
	
    <!-- Detailed Price Info -->
    <h3>Current Bidding</h3>
    <p>
        <strong>Current Price:</strong> $<%= auctionDetails.get("current_price") %>
        <% if (currentHighBid > 0) { %>
            (There are active bids)
        <% } else { %>
            (This is the Starting Price)
        <% } %>
    </p>
    <p><strong>Minimum Next Bid:</strong> $<%= auctionDetails.get("next_bid") %></p>
    <p><strong>Minimum Increment:</strong> $<%= auctionDetails.get("increment") %></p>
    
    <% if (!status.startsWith("CLOSED") && !status.startsWith("REMOVED")) { %>
        <div class="bid-area">
            
            <!-- Bid Forms (Only visible if OPEN) -->
            <h3>Place a Bid</h3>
            <p>Your current maximum auto-bid limit for this item is: 
                <strong>$<%= auctionDetails.get("user_max_limit") %></strong>
            </p>
            
            <hr>

            <!-- 1. MANUAL BID FORM -->
            <h4>1. Manual Bid</h4>
            <form action="process_bid.jsp" method="POST">
                <input type="hidden" name="auction_id" value="<%= auctionIdStr %>">
                <input type="hidden" name="bid_type" value="manual">
                
                <label for="manual_bid">Your Bid Amount:</label>
                <!-- Manual bid must be at least the calculated minimum next bid -->
                <!-- The 'min' attribute here will now correctly allow init_price for the first bid -->
                <input type="number" id="manual_bid" name="bid_amount" 
                       min="<%= auctionDetails.get("next_bid") %>" step="0.01" required>
                
                <input type="submit" value="Submit Manual Bid">
            </form>
            
            <hr>
            
            <!-- 2. AUTOMATIC BIDDING SETUP FORM -->
            <h4>2. Set Auto-Bidding Limit (Reserve)</h4>
            <p>The system will automatically bid for you up to this limit.</p>
            <form action="process_bid.jsp" method="POST">
                <input type="hidden" name="auction_id" value="<%= auctionIdStr %>">
                <input type="hidden" name="bid_type" value="auto">
                
                <label for="max_limit">Your SECRET Max Limit:</label>
                <input type="number" id="max_limit" name="max_limit" 
                       min="<%= auctionDetails.get("next_bid") %>" step="0.01" required>
                       
                <input type="submit" value="Set/Update Auto-Bid Limit">
            </form>
        </div>
    <% } %>
    
    <hr>
    
    <!-- Item Description and Dynamic Fields -->
    <h3>Item Description</h3>
    <p><%= auctionDetails.get("description") %></p>
    
    <% if (!itemFields.isEmpty()) { %>
        <h4>Specific Characteristics</h4>
        <ul>
            <% for (Map<String, String> field : itemFields) { %>
                <li><strong><%= field.get("name") %>:</strong> <%= field.get("value") %></li>
            <% } %>
        </ul>
    <% } %>

    <hr>

    <!-- Bid History Section -->
    <h3>Bid History (<%= bidHistory.size() %> total bids)</h3>
    <% if (bidHistory.isEmpty()) { %>
        <p>No bids have been placed yet.</p>
    <% } else { %>
        <table border="1">
            <tr><th>Bidder (Username)</th><th>Amount</th><th>Time</th></tr>
            <% for (Map<String, String> bid : bidHistory) { %>
                <tr>
                    <td><a href="bid_history_public.jsp?user_id=<%= bid.get("user_id") %>">
                        <%= bid.get("username") %> </a></td>
                    <td>$<%= bid.get("amount") %></td>
                    <td><%= bid.get("time") %></td>
                </tr>
            <% } %>
        </table>
    <% } %>
    
</body>
</html> 