<%@ page language="java" contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" import="com.cs336.pkg.*, java.sql.*, java.util.*" %>

<%
    // Get auction_id
    String auctionIdStr = request.getParameter("id");
    if (auctionIdStr == null) {
        out.println("Invalid auction.");
        return;
    }
    int auctionId = Integer.parseInt(auctionIdStr);

    // Get subcategory_id of the current auction
    ApplicationDB db0 = new ApplicationDB();
    Connection con0 = db0.getConnection();

    int subcatId = -1;

    try {
        PreparedStatement ps0 = con0.prepareStatement(
                "SELECT subcat_id FROM Auction WHERE auction_id = ?"
        );
        ps0.setInt(1, auctionId);
        ResultSet rs0 = ps0.executeQuery();

        if (rs0.next()) {
            subcatId = rs0.getInt("subcat_id");
        }
        rs0.close();
        ps0.close();
    } finally {
        db0.closeConnection(con0);
    }

    if (subcatId == -1) {
        out.println("Auction not found.");
        return;
    }

    //  Search and Sort Parameters

    String keyword = request.getParameter("keyword");
    if (keyword == null) keyword = "";

    String status = request.getParameter("status");
    if (status == null) status = "";

    String sort = request.getParameter("sort");
    if (sort == null) sort = "endtime";

    // ORDER BY
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

    // SQL
    String sql =
            "SELECT a.auction_id, a.item_name, a.close_time, a.min_price, a.init_price, " +
                    "       s.name AS subcat_name, " +
                    "       (SELECT MAX(b.bid_amount) FROM Bid_History b WHERE b.auction_id=a.auction_id) AS max_bid, " +
                    "       COALESCE((SELECT MAX(b.bid_amount) FROM Bid_History b WHERE b.auction_id=a.auction_id), a.init_price) AS effective_price " +
                    "FROM Auction a " +
                    "JOIN SubCategory s ON a.subcat_id = s.subcat_id " +
                    "WHERE a.subcat_id = ? " +
                    "  AND a.auction_id <> ? " +
                    "  AND a.close_time >= DATE_SUB(NOW(), INTERVAL 1 MONTH) ";

    // Keyword filter
    if (!keyword.isEmpty()) sql += " AND a.item_name LIKE ? ";

    // Status filter
    if (status.equals("open")) {
        sql += " AND a.close_time > NOW() AND a.is_removed = FALSE ";
    } else if (status.equals("sold")) {
        sql += " AND a.close_time <= NOW() AND " +
                " COALESCE((SELECT MAX(b.bid_amount) FROM Bid_History b WHERE b.auction_id=a.auction_id), 0) >= a.min_price ";
    } else if (status.equals("unsold")) {
        sql += " AND a.close_time <= NOW() AND " +
                " COALESCE((SELECT MAX(b.bid_amount) FROM Bid_History b WHERE b.auction_id=a.auction_id), 0) < a.min_price ";
    }

    sql += " " + orderBy;

    //  Execute Query

    ApplicationDB db = new ApplicationDB();
    Connection con = db.getConnection();
    PreparedStatement ps = null;
    ResultSet rs = null;

    List<Map<String,String>> similarItems = new ArrayList<>();

    try {
        ps = con.prepareStatement(sql);

        int idx = 1;
        ps.setInt(idx++, subcatId);
        ps.setInt(idx++, auctionId);

        if (!keyword.isEmpty()) ps.setString(idx++, "%" + keyword + "%");

        rs = ps.executeQuery();

        while (rs.next()) {
            Map<String,String> row = new HashMap<>();

            row.put("id", rs.getString("auction_id"));
            row.put("name", rs.getString("item_name"));
            row.put("subcat_name", rs.getString("subcat_name"));
            row.put("close_time", rs.getString("close_time"));

            float maxBid = rs.getFloat("max_bid");
            float initPrice = rs.getFloat("init_price");
            float curr = (maxBid > 0) ? maxBid : initPrice;

            Timestamp ct = rs.getTimestamp("close_time");
            boolean isRemoved = false;

            String itemStatus;
            long now = System.currentTimeMillis();
            if (now > ct.getTime()) {
                if (maxBid >= rs.getFloat("min_price")) itemStatus = "SOLD";
                else itemStatus = "UNSOLD";
            } else itemStatus = "OPEN";

            row.put("status", itemStatus);
            row.put("current_price", String.format("%.2f", curr));

            similarItems.add(row);
        }
    } catch (Exception e) {
        out.println("Error loading similar items: " + e.getMessage());
    } finally {
        if (rs != null) rs.close();
        if (ps != null) ps.close();
        db.closeConnection(con);
    }
%>

<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Similar Items</title>
    <style>
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; border: 1px solid #ccc; }
        th { background: #f0f0f0; }
    </style>
</head>
<body>

<h2>Similar Items (Last 30 Days)</h2>

<!-- Search Form -->
<form method="GET">
    <input type="hidden" name="id" value="<%= auctionId %>">

    Keyword:
    <input type="text" name="keyword" value="<%= keyword %>">

    Status:
    <select name="status">
        <option value="">All</option>
        <option value="open" <%= status.equals("open") ? "selected" : "" %>>OPEN</option>
        <option value="sold" <%= status.equals("sold") ? "selected" : "" %>>SOLD</option>
        <option value="unsold" <%= status.equals("unsold") ? "selected" : "" %>>UNSOLD</option>
    </select>

    <button type="submit">Search</button>
</form>

<!-- Sort Form -->
<form method="GET">
    <input type="hidden" name="id" value="<%= auctionId %>">
    <input type="hidden" name="keyword" value="<%= keyword %>">
    <input type="hidden" name="status" value="<%= status %>">
    <label>Sort:</label>
    <select name="sort">
        <option value="endtime" <%= sort.equals("endtime") ? "selected" : "" %>>Ending Soon</option>
        <option value="price_asc" <%= sort.equals("price_asc") ? "selected" : "" %>>Price Low→High</option>
        <option value="price_desc" <%= sort.equals("price_desc") ? "selected" : "" %>>Price High→Low</option>
        <option value="type" <%= sort.equals("type") ? "selected" : "" %>>Category</option>
    </select>
    <button type="submit">Sort</button>
</form>

<hr>

<%
    if (similarItems.isEmpty()) {
%>
<p>No similar items found.</p>
<%
} else {
%>

<table>
    <tr>
        <th>Category</th>
        <th>Item</th>
        <th>Status</th>
        <th>Price</th>
        <th>Close Time</th>
        <th>Action</th>
    </tr>

    <% for (Map<String,String> row : similarItems) { %>
    <tr>
        <td><%= row.get("subcat_name") %></td>
        <td><%= row.get("name") %></td>
        <td><%= row.get("status") %></td>
        <td>$<%= row.get("current_price") %></td>
        <td><%= row.get("close_time") %></td>
        <td><a href="auction_detail.jsp?id=<%= row.get("id") %>">View</a></td>
    </tr>
    <% } %>

</table>

<% } %>

<br>
<a href="auction_detail.jsp?id=<%= auctionId %>">← Back to Auction</a>

</body>
</html>
 