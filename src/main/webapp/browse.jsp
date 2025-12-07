<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" import="com.cs336.pkg.*, java.sql.*, java.util.*" %>
<%
    // Auth Guard
    Integer userId = (Integer) session.getAttribute("user_id");
    if (userId == null) {
        response.sendRedirect("index.jsp");
        return;
    }
    String keyword = request.getParameter("keyword");
    String category = request.getParameter("category");
    if (keyword == null) keyword = "";
    if (category == null) category = "";


    ApplicationDB db = new ApplicationDB();
    Connection con = db.getConnection();
    Statement stmt = null;
    ResultSet rs = null;
    
    // AUTO-CLEANUP LOGIC (Lazy Closing on Browse) ---
    // Check for auctions that have closed but haven't been processed yet.
    // We identify them by: close_time < NOW() AND NOT EXISTS (Inbox message of type 'AUCTION_ENDED' for the seller)
    // We use the seller alert as the "processed flag".
    //  Load categories for dropdown

    Map<String, List<String[]>> categoriesMap = new LinkedHashMap<>();

    try {
        String sqlCat =
                "SELECT c.name AS cat_name, s.subcat_id, s.name AS subcat_name " +
                        "FROM Category c JOIN SubCategory s ON c.cat_id = s.cat_id " +
                        "ORDER BY c.name, s.name";

        PreparedStatement psCat = con.prepareStatement(sqlCat);
        ResultSet rsCat = psCat.executeQuery();

        while (rsCat.next()) {
            String catName = rsCat.getString("cat_name");
            String subId = rsCat.getString("subcat_id");
            String subName = rsCat.getString("subcat_name");

            categoriesMap.putIfAbsent(catName, new ArrayList<>());
            categoriesMap.get(catName).add(new String[]{subId, subName});
        }

        rsCat.close();
        psCat.close();

    } catch (Exception e) {
        out.println("Category load error: " + e.getMessage());
    }

    try {
        // Find candidates for closing (Expired auctions not yet processed)
        // We need the seller_id now too.
        String cleanupSql = "SELECT a.auction_id, a.item_name, a.min_price, a.seller_id, " +
                            "(SELECT user_id FROM Bid_History b WHERE b.auction_id = a.auction_id ORDER BY bid_amount DESC LIMIT 1) as winner_id, " +
                            "(SELECT bid_amount FROM Bid_History b WHERE b.auction_id = a.auction_id ORDER BY bid_amount DESC LIMIT 1) as max_bid " +
                            "FROM Auction a " +
                            "WHERE a.close_time < NOW() AND a.is_removed = FALSE " +
                            "AND NOT EXISTS (SELECT 1 FROM Inbox i WHERE i.auction_id = a.auction_id AND i.message_type = 'AUCTION_ENDED') " +
                            "LIMIT 50";
                            
        PreparedStatement psCleanup = con.prepareStatement(cleanupSql);
        ResultSet rsCleanup = psCleanup.executeQuery();
        
        while (rsCleanup.next()) {
            int cAuctionId = rsCleanup.getInt("auction_id");
            String cItemName = rsCleanup.getString("item_name");
            float cMinPrice = rsCleanup.getFloat("min_price");
            int cSellerId = rsCleanup.getInt("seller_id");
            int cWinnerId = rsCleanup.getInt("winner_id");
            float cMaxBid = rsCleanup.getFloat("max_bid");
            
            if (rsCleanup.wasNull()) cWinnerId = -1; // No bids
            
            // Determine Sold or Unsold
            boolean isSold = (cWinnerId != -1 && cMaxBid >= cMinPrice);
            
            if (isSold) {
                // 1. Notify Winner ('AUCTION_WON')
                String winMsg = "Congratulations! You won the auction for '" + cItemName + "' with a bid of $" + String.format("%.2f", cMaxBid) + ".";
                String insertWin = "INSERT INTO Inbox (user_id, message_type, auction_id, message_body) VALUES (?, 'AUCTION_WON', ?, ?)";
                try (PreparedStatement psIns = con.prepareStatement(insertWin)) {
                    psIns.setInt(1, cWinnerId);
                    psIns.setInt(2, cAuctionId);
                    psIns.setString(3, winMsg);
                    psIns.executeUpdate();
                }
                
                // 2. Notify Seller ('AUCTION_ENDED') - SOLD
                String soldMsg = "Your item '" + cItemName + "' was SOLD for $" + String.format("%.2f", cMaxBid) + ".";
                String insertSold = "INSERT INTO Inbox (user_id, message_type, auction_id, message_body) VALUES (?, 'AUCTION_ENDED', ?, ?)";
                try (PreparedStatement psIns = con.prepareStatement(insertSold)) {
                    psIns.setInt(1, cSellerId);
                    psIns.setInt(2, cAuctionId);
                    psIns.setString(3, soldMsg);
                    psIns.executeUpdate();
                }
                
            } else {
                 // 3. Notify Seller ('AUCTION_ENDED') - UNSOLD
                 String unsoldMsg = "Your item '" + cItemName + "' closed UNSOLD (Reserve not met or no bids).";
                 String insertUnsold = "INSERT INTO Inbox (user_id, message_type, auction_id, message_body) VALUES (?, 'AUCTION_ENDED', ?, ?)";
                 try (PreparedStatement psIns = con.prepareStatement(insertUnsold)) {
                     psIns.setInt(1, cSellerId);
                     psIns.setInt(2, cAuctionId);
                     psIns.setString(3, unsoldMsg);
                     psIns.executeUpdate();
                 }
            }
        }
        if (rsCleanup != null) rsCleanup.close();
        if (psCleanup != null) psCleanup.close();
        
    } catch (Exception e) {
        // Ignore cleanup errors, don't block browse
        System.out.println("Auto-cleanup warning: " + e.getMessage());
    }

    // --- END AUTO-CLEANUP ---


    // List to store auction items data
    List<Map<String, String>> auctions = new ArrayList<>();

    try {
        // --- NEW: Read sorting method from request ---
        String sort = request.getParameter("sort");
        if (sort == null) sort = "endtime";

        String orderBy = "";

        switch (sort) {
            case "price_asc":
                orderBy = "ORDER BY effective_price ASC";
                break;
            case "price_desc":
                orderBy = "ORDER BY effective_price DESC";
                break;
            case "type":
                orderBy = "ORDER BY s.name ASC";
                break;
            default:
                orderBy = "ORDER BY a.close_time ASC";
        }

        // Query to get open auctions
        // Logic: Fetch items that are NOT removed AND whose closing time is in the future
        String sql =
                "SELECT a.auction_id, a.item_name, a.init_price, a.close_time, " +
                        "       s.name AS subcat_name, " +
                        "       (SELECT CASE WHEN MAX(b.bid_amount) > 0 THEN MAX(b.bid_amount) ELSE a.init_price END " +
                        "        FROM Bid_History b WHERE b.auction_id = a.auction_id) AS effective_price " +
                        "FROM Auction a " +
                        "JOIN SubCategory s ON a.subcat_id = s.subcat_id " +
                        "WHERE a.is_removed = FALSE " +
                        "AND a.close_time > NOW() " ;
        // add keyword
        if (!keyword.isEmpty()) sql += " AND a.item_name LIKE ? ";
        // category filters
        if (!category.isEmpty()) sql += " AND s.subcat_id = ? ";
        sql += orderBy;

        PreparedStatement ps = con.prepareStatement(sql);

        int idx = 1;
        if (!keyword.isEmpty()) ps.setString(idx++, "%" + keyword + "%");
        if (!category.isEmpty()) ps.setInt(idx++, Integer.parseInt(category));

        rs = ps.executeQuery();
                     


        while (rs.next()) {
            Map<String, String> item = new HashMap<>();
            item.put("id", rs.getString("auction_id"));
            item.put("name", rs.getString("item_name"));
            item.put("close_time", rs.getString("close_time"));
            item.put("subcat_name", rs.getString("subcat_name"));
            
            float initPrice = rs.getFloat("init_price");
            float effectivePrice = rs.getFloat("effective_price");

            if (effectivePrice > initPrice) {
                item.put("price", String.format("%.2f", effectivePrice));
                item.put("price_label", "Current Bid");
            } else {
                item.put("price", String.format("%.2f", initPrice));
                item.put("price_label", "Starting Price");
            }
            
            auctions.add(item);
        }

    } catch (Exception e) {
        out.println("Error loading auctions: " + e.getMessage());
    } finally {
        if (rs != null) rs.close();
        if (stmt != null) stmt.close();
        if (con != null) db.closeConnection(con);
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>Browse Auctions</title>
    <style>
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; border: 1px solid #ccc; text-align: left; }
        th { background-color: #f2f2f2; }
    </style>
</head>
<body>
    <h2>Available Auctions</h2>
    <form method="GET" action="browse.jsp">
        <h3>Search Filters</h3>

        Item Name:
        <input type="text" name="keyword">

        Category:
        <select name="category">
            <option value="">All</option>
            <%
                for (Map.Entry<String, List<String[]>> entry : categoriesMap.entrySet()) {
            %>
            <optgroup label="<%= entry.getKey() %>">
                <%
                    for (String[] sub : entry.getValue()) {
                        String id = sub[0];
                        String name = sub[1];
                %>
                <option value="<%= id %>" <%= id.equals(category) ? "selected" : "" %>>
                    <%= name %>
                </option>
                <% }} %>
            </optgroup>
        </select>


        <button type="submit">Search</button>
    </form>
    <form method="get" action="browse.jsp">


        <label>Sort by: </label>
        <select name="sort">
            <option value="endtime">Ending Soon</option>
            <option value="price_asc">Price (Low → High)</option>
            <option value="price_desc">Price (High → Low)</option>
            <option value="type">Category</option>
        </select>
        <button type="submit">Apply</button>
    </form>
    <hr>

    
    <!-- Navigation Links -->
    <a href="welcome_user.jsp">Back to Dashboard</a>
    
    <hr>
    
    <% if (auctions.isEmpty()) { %>
        <p>No active auctions found at this moment.</p>
    <% } else { %>
        <table>
            <thead>
                <tr>
                    <th>Category</th>

                    <th>Item Name</th>
                    <th>Price Info</th>
                    <th>Closes At</th>
                    <th>Action</th>
                </tr>
            </thead>
            <tbody>
                <% for (Map<String, String> item : auctions) { %>
                    <tr>
                        <td><%= item.get("subcat_name") %></td>
                        <td><%= item.get("name") %></td>
                        <td>
                            <strong><%= item.get("price_label") %>:</strong> 
                            $<%= item.get("price") %>
                        </td>
                        <td><%= item.get("close_time") %></td>
                        <td>
                            <a href="auction_detail.jsp?id=<%= item.get("id") %>">
                                View Item
                            </a>
                        </td>
                    </tr>
                <% } %>
            </tbody>
        </table>
    <% } %>
    
</body>
</html> 