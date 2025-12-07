<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" import="com.cs336.pkg.*, java.sql.*, java.util.*" %>
<%
    Integer userId = (Integer) session.getAttribute("user_id");
    String usertype = (String) session.getAttribute("usertype");
    
    if (userId == null || !usertype.equals("admin")) {
        response.sendRedirect("index.jsp");
        return;
    }
    
    ApplicationDB db = new ApplicationDB();
    Connection con = db.getConnection();
    
    // Total Earnings
    float totalEarnings = 0;
    
    // Earnings per Item
    List<Map<String, String>> itemEarnings = new ArrayList<>();
    
    // Earnings per Item Type
    List<Map<String, String>> typeEarnings = new ArrayList<>();
    
    // Earnings per End-User 
    List<Map<String, String>> sellerEarnings = new ArrayList<>();
    
    // Best-Selling Items
    List<Map<String, String>> bestItems = new ArrayList<>();
    
    // Best Buyers
    List<Map<String, String>> bestBuyers = new ArrayList<>();
    
    try {
        // Compute total earnings
        String sqlTotal = 
            "SELECT COALESCE(SUM(b.bid_amount), 0) AS total " +
            "FROM Bid_History b " +
            "JOIN Auction a ON b.auction_id = a.auction_id " +
            "WHERE a.close_time < NOW() " +
            "AND a.is_removed = FALSE " +
            "AND b.bid_amount >= a.min_price " +
            "AND b.bid_amount = (SELECT MAX(bid_amount) FROM Bid_History WHERE auction_id = a.auction_id)";
        
        PreparedStatement ps = con.prepareStatement(sqlTotal);
        ResultSet rs = ps.executeQuery();
        if (rs.next()) totalEarnings = rs.getFloat("total");
        rs.close();
        ps.close();
        
        // Computer total earnings per item
        String sqlItem = 
            "SELECT a.item_name, a.auction_id, MAX(b.bid_amount) AS earnings " +
            "FROM Auction a " +
            "JOIN Bid_History b ON a.auction_id = b.auction_id " +
            "WHERE a.close_time < NOW() " +
            "AND a.is_removed = FALSE " +
            "AND b.bid_amount >= a.min_price " +
            "AND b.bid_amount = (SELECT MAX(bid_amount) FROM Bid_History WHERE auction_id = a.auction_id) " +
            "GROUP BY a.auction_id " +
            "ORDER BY earnings DESC " +
            "LIMIT 10";
        
        ps = con.prepareStatement(sqlItem);
        rs = ps.executeQuery();
        while (rs.next()) {
            Map<String, String> item = new HashMap<>();
            item.put("name", rs.getString("item_name"));
            item.put("auction_id", rs.getString("auction_id"));
            item.put("earnings", String.format("%.2f", rs.getFloat("earnings")));
            itemEarnings.add(item);
        }
        rs.close();
        ps.close();
        
        // Computer total earnings per item type
        String sqlType = 
            "SELECT s.name AS subcat_name, COALESCE(SUM(b.bid_amount), 0) AS earnings " +
            "FROM SubCategory s " +
            "LEFT JOIN Auction a ON s.subcat_id = a.subcat_id " +
            "LEFT JOIN Bid_History b ON a.auction_id = b.auction_id " +
            "WHERE (a.close_time < NOW() OR a.close_time IS NULL) " +
            "AND (a.is_removed = FALSE OR a.is_removed IS NULL) " +
            "AND (b.bid_amount >= a.min_price OR b.bid_amount IS NULL) " +
            "AND (b.bid_amount = (SELECT MAX(bid_amount) FROM Bid_History WHERE auction_id = a.auction_id) OR b.bid_amount IS NULL) " +
            "GROUP BY s.subcat_id " +
            "ORDER BY earnings DESC";
        
        ps = con.prepareStatement(sqlType);
        rs = ps.executeQuery();
        while (rs.next()) {
            Map<String, String> type = new HashMap<>();
            type.put("name", rs.getString("subcat_name"));
            type.put("earnings", String.format("%.2f", rs.getFloat("earnings")));
            typeEarnings.add(type);
        }
        rs.close();
        ps.close();
        
        // Compute total earnings per seller
        String sqlSeller = 
            "SELECT u.username, u.user_id, COALESCE(SUM(b.bid_amount), 0) AS earnings " +
            "FROM User u " +
            "LEFT JOIN Auction a ON u.user_id = a.seller_id " +
            "LEFT JOIN Bid_History b ON a.auction_id = b.auction_id " +
            "WHERE u.usertype = 'user' " +
            "AND (a.close_time < NOW() OR a.close_time IS NULL) " +
            "AND (a.is_removed = FALSE OR a.is_removed IS NULL) " +
            "AND (b.bid_amount >= a.min_price OR b.bid_amount IS NULL) " +
            "AND (b.bid_amount = (SELECT MAX(bid_amount) FROM Bid_History WHERE auction_id = a.auction_id) OR b.bid_amount IS NULL) " +
            "GROUP BY u.user_id " +
            "HAVING earnings > 0 " +
            "ORDER BY earnings DESC " +
            "LIMIT 10";
        
        ps = con.prepareStatement(sqlSeller);
        rs = ps.executeQuery();
        while (rs.next()) {
            Map<String, String> seller = new HashMap<>();
            seller.put("username", rs.getString("username"));
            seller.put("user_id", rs.getString("user_id"));
            seller.put("earnings", String.format("%.2f", rs.getFloat("earnings")));
            sellerEarnings.add(seller);
        }
        rs.close();
        ps.close();
        
        // Find top 10 best-selling items
        String sqlBestItems = 
            "SELECT a.item_name, a.auction_id, COUNT(b.bid_id) AS bid_count, MAX(b.bid_amount) AS final_price " +
            "FROM Auction a " +
            "JOIN Bid_History b ON a.auction_id = b.auction_id " +
            "WHERE a.close_time < NOW() " +
            "AND a.is_removed = FALSE " +
            "GROUP BY a.auction_id " +
            "ORDER BY bid_count DESC " +
            "LIMIT 10";
        
        ps = con.prepareStatement(sqlBestItems);
        rs = ps.executeQuery();
        while (rs.next()) {
            Map<String, String> item = new HashMap<>();
            item.put("name", rs.getString("item_name"));
            item.put("auction_id", rs.getString("auction_id"));
            item.put("bid_count", rs.getString("bid_count"));
            item.put("final_price", String.format("%.2f", rs.getFloat("final_price")));
            bestItems.add(item);
        }
        rs.close();
        ps.close();
        
        // Find top 10 best buyers
        String sqlBuyers = 
            "SELECT u.username, u.user_id, COALESCE(SUM(b.bid_amount), 0) AS total_spent " +
            "FROM User u " +
            "JOIN Bid_History b ON u.user_id = b.user_id " +
            "JOIN Auction a ON b.auction_id = a.auction_id " +
            "WHERE a.close_time < NOW() " +
            "AND a.is_removed = FALSE " +
            "AND b.bid_amount >= a.min_price " +
            "AND b.bid_amount = (SELECT MAX(bid_amount) FROM Bid_History WHERE auction_id = a.auction_id) " +
            "GROUP BY u.user_id " +
            "HAVING total_spent > 0 " +
            "ORDER BY total_spent DESC " +
            "LIMIT 10";
        
        ps = con.prepareStatement(sqlBuyers);
        rs = ps.executeQuery();
        while (rs.next()) {
            Map<String, String> buyer = new HashMap<>();
            buyer.put("username", rs.getString("username"));
            buyer.put("user_id", rs.getString("user_id"));
            buyer.put("spent", String.format("%.2f", rs.getFloat("total_spent")));
            bestBuyers.add(buyer);
        }
        rs.close();
        ps.close();
        
    } finally {
        db.closeConnection(con);
    }
%>

<!DOCTYPE html>
<html>
<head>
    <title>Sales Reports</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 10px; border: 1px solid #ccc; text-align: left; }
        th { background-color: #f2f2f2; font-weight: bold; }
        .highlight { background-color: #ffffcc; font-size: 1.8em; padding: 20px; 
                     border: 2px solid #ff9900; margin: 20px 0; text-align: center; }
        h2 { color: #333; border-bottom: 2px solid #666; padding-bottom: 10px; }
        h3 { color: #666; margin-top: 30px; }
    </style>
</head>
<body>
    <h2>BuyMe Sales Reports</h2>
    
    <div class="highlight">
        <strong>Total Earnings:</strong> $<%= String.format("%.2f", totalEarnings) %>
    </div>
    
    <h3>Top 10 Highest-Earning Auctions</h3>
    <% if (itemEarnings.isEmpty()) { %>
        <p>No completed auctions yet.</p>
    <% } else { %>
        <table>
            <tr>
                <th>Rank</th>
                <th>Item Name</th>
                <th>Final Price</th>
                <th>Action</th>
            </tr>
            <% 
            int rank1 = 1;  
            for (Map<String, String> item : itemEarnings) { 
            %>
                <tr>
                    <td><%= rank1++ %></td>
                    <td><%= item.get("name") %></td>
                    <td>$<%= item.get("earnings") %></td>
                    <td><a href="auction_detail.jsp?id=<%= item.get("auction_id") %>">View</a></td>
                </tr>
            <% } %>
        </table>
    <% } %>
    
    <h3>Earnings by Item Type (Category)</h3>
    <% if (typeEarnings.isEmpty()) { %>
        <p>No data available.</p>
    <% } else { %>
        <table>
            <tr>
                <th>Category</th>
                <th>Total Earnings</th>
            </tr>
            <% for (Map<String, String> type : typeEarnings) { %>
                <tr>
                    <td><%= type.get("name") %></td>
                    <td>$<%= type.get("earnings") %></td>
                </tr>
            <% } %>
        </table>
    <% } %>
    
    <h3>Top 10 Sellers by Earnings</h3>
    <% if (sellerEarnings.isEmpty()) { %>
        <p>No seller data available.</p>
    <% } else { %>
        <table>
            <tr>
                <th>Rank</th>
                <th>Seller Username</th>
                <th>Total Earned</th>
                <th>Action</th>
            </tr>
            <% 
            int rank2 = 1; 
            for (Map<String, String> seller : sellerEarnings) { 
            %>
                <tr>
                    <td><%= rank2++ %></td>
                    <td><%= seller.get("username") %></td>
                    <td>$<%= seller.get("earnings") %></td>
                    <td><a href="my_listings_public.jsp?user_id=<%= seller.get("user_id") %>">View Listings</a></td>
                </tr>
            <% } %>
        </table>
    <% } %>
    
    <h3>Best-Selling Items (Most Popular by Bid Count)</h3>
    <% if (bestItems.isEmpty()) { %>
        <p>No data available.</p>
    <% } else { %>
        <table>
            <tr>
                <th>Rank</th>
                <th>Item Name</th>
                <th>Total Bids</th>
                <th>Final Price</th>
                <th>Action</th>
            </tr>
            <% 
            int rank3 = 1;  
            for (Map<String, String> item : bestItems) { 
            %>
                <tr>
                    <td><%= rank3++ %></td>
                    <td><%= item.get("name") %></td>
                    <td><%= item.get("bid_count") %> bids</td>
                    <td>$<%= item.get("final_price") %></td>
                    <td><a href="auction_detail.jsp?id=<%= item.get("auction_id") %>">View</a></td>
                </tr>
            <% } %>
        </table>
    <% } %>
    
    <h3>Top 10 Buyers by Total Spending</h3>
    <% if (bestBuyers.isEmpty()) { %>
        <p>No buyer data available.</p>
    <% } else { %>
        <table>
            <tr>
                <th>Rank</th>
                <th>Buyer Username</th>
                <th>Total Spent</th>
                <th>Action</th>
            </tr>
            <% 
            int rank4 = 1;
            for (Map<String, String> buyer : bestBuyers) { 
            %>
                <tr>
                    <td><%= rank4++ %></td>
                    <td><%= buyer.get("username") %></td>
                    <td>$<%= buyer.get("spent") %></td>
                    <td><a href="bid_history_public.jsp?user_id=<%= buyer.get("user_id") %>">View History</a></td>
                </tr>
            <% } %>
        </table>
    <% } %>
    
    <br><br>
    <a href="welcome_admin.jsp">← Back to Admin Dashboard</a>
</body>
</html>