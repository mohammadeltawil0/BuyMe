<%@ page language="java" contentType="text/html; charset=UTF-8"
         pageEncoding="UTF-8" import="com.cs336.pkg.*, java.sql.*, java.util.*" %>

<%

  // Auth Guard

  Integer userId = (Integer) session.getAttribute("user_id");
  if (userId == null) {
    response.sendRedirect("index.jsp");
    return;
  }

  // Get owner user_id (support viewing others)
  String ownerIdStr = request.getParameter("user_id");
  int ownerId = (ownerIdStr == null || ownerIdStr.isEmpty())
          ? userId            // 默认显示自己的
          : Integer.parseInt(ownerIdStr);

// Fetch username for display
  String username = "";
  ApplicationDB dbUser = new ApplicationDB();
  Connection conUser = dbUser.getConnection();

  try {
    PreparedStatement psUser = conUser.prepareStatement(
            "SELECT username FROM User WHERE user_id = ?"
    );
    psUser.setInt(1, ownerId);
    ResultSet rsUser = psUser.executeQuery();
    if (rsUser.next()) {
      username = rsUser.getString("username");
    }
    rsUser.close();
    psUser.close();
  } finally {
    dbUser.closeConnection(conUser);
  }


  // Get search and sort parameters

  String keyword = request.getParameter("keyword");
  String category = request.getParameter("category");

  String status = request.getParameter("status");

  if (keyword == null) keyword = "";
  if (category == null) category = "";

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
  //  Load categories for dropdown
  ApplicationDB dbCat = new ApplicationDB();
  Connection conCat = dbCat.getConnection();

  Map<String, List<String[]>> categoriesMap = new LinkedHashMap<>();

  try {
    String sqlCat =
            "SELECT c.name AS cat_name, s.subcat_id, s.name AS subcat_name " +
                    "FROM Category c JOIN SubCategory s ON c.cat_id = s.cat_id " +
                    "ORDER BY c.name, s.name";

    PreparedStatement psCat = conCat.prepareStatement(sqlCat);
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
  } finally {
    if (conCat != null) dbCat.closeConnection(conCat);
  }



  // Build SQL

  String sql =
          "SELECT a.auction_id, a.item_name, a.init_price, a.min_price, " +
                  "       a.close_time, a.is_removed, s.name AS subcat_name, " +
                  "       (SELECT MAX(b.bid_amount) FROM Bid_History b WHERE b.auction_id=a.auction_id) AS max_bid, " +
                  "       COALESCE((SELECT MAX(b.bid_amount) FROM Bid_History b WHERE b.auction_id=a.auction_id), a.init_price) AS effective_price " +
                  "FROM Auction a " +
                  "LEFT JOIN SubCategory s ON a.subcat_id = s.subcat_id " +
                  "WHERE a.seller_id = ? ";


  // add keyword
  if (!keyword.isEmpty()) sql += " AND a.item_name LIKE ? ";

  // category filters
  if (!category.isEmpty()) sql += " AND s.subcat_id = ? ";


  // status filters
  if (status.equals("open")) {
    sql += " AND a.close_time > NOW() AND a.is_removed = FALSE ";
  }
  else if (status.equals("sold")) {
    sql += " AND a.close_time <= NOW() AND " +
            " COALESCE((SELECT MAX(b.bid_amount) FROM Bid_History b WHERE b.auction_id=a.auction_id), 0) >= a.min_price ";
  }
  else if (status.equals("unsold")) {
    sql += " AND a.close_time <= NOW() AND " +
            " COALESCE((SELECT MAX(b.bid_amount) FROM Bid_History b WHERE b.auction_id=a.auction_id), 0) < a.min_price ";
  }


  sql += " " + orderBy;

  ApplicationDB db = new ApplicationDB();
  Connection con = db.getConnection();
  PreparedStatement ps = null;
  ResultSet rs = null;

  List<Map<String,String>> listings = new ArrayList<>();

  try {
    ps = con.prepareStatement(sql);

    int idx = 1;
    ps.setInt(idx++, ownerId);

    if (!keyword.isEmpty()) ps.setString(idx++, "%" + keyword + "%");
    if (!category.isEmpty()) ps.setInt(idx++, Integer.parseInt(category));

    rs = ps.executeQuery();

    while (rs.next()) {
      Map<String,String> item = new HashMap<>();

      item.put("id", rs.getString("auction_id"));
      item.put("name", rs.getString("item_name"));
      item.put("subcat_name", rs.getString("subcat_name"));
      item.put("close_time", rs.getString("close_time"));
      item.put("min_price", String.format("%.2f", rs.getFloat("min_price")));

      float maxBid = rs.getFloat("max_bid");
      float initPrice = rs.getFloat("init_price");
      float currPrice = (maxBid > 0) ? maxBid : initPrice;

      Timestamp closeTime = rs.getTimestamp("close_time");
      boolean isRemoved = rs.getBoolean("is_removed");
      long now = System.currentTimeMillis();

      String itemstatus;
      if (isRemoved) {
        itemstatus = "REMOVED";
      } else if (now > closeTime.getTime()) {
        if (maxBid >= rs.getFloat("min_price")) itemstatus = "SOLD";
        else itemstatus = "UNSOLD";
      } else {
        itemstatus = "OPEN";
      }

      item.put("status", itemstatus);
      item.put("current_price", String.format("%.2f", currPrice));

      listings.add(item);
    }

  } catch (Exception e) {
    out.println("Error loading listings: " + e.getMessage());
  } finally {
    if (rs != null) rs.close();
    if (ps != null) ps.close();
    if (con != null) db.closeConnection(con);
  }
%>

<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>My Auction Listings</title>
  <style>
    table { width: 100%; border-collapse: collapse; }
    th, td { padding: 10px; border: 1px solid #ccc; text-align: left; }
    th { background-color: #f2f2f2; }
  </style>
</head>

<body>
<h2>Auctions by <%= username %></h2>

<!-- Search Form -->
<form method="GET">
  <input type="hidden" name="user_id" value="<%= ownerId %>">
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



  Status:
  <select name="status">
    <option value="">All</option>
    <option value="open">OPEN</option>
    <option value="sold">SOLD</option>
    <option value="unsold">UNSOLD</option>
  </select>

  <button type="submit">Search</button>
</form>


<!-- Sorting Form -->
<form method="GET">
  <input type="hidden" name="keyword" value="<%= keyword %>">
  <input type="hidden" name="category" value="<%= category %>">
  <input type="hidden" name="status" value="<%= status %>">
  <input type="hidden" name="user_id" value="<%= ownerId %>">
  <label>Sort by:</label>
  <select name="sort">
    <option value="endtime" <%= sort.equals("endtime") ? "selected" : "" %>>Ending Soon</option>
    <option value="price_asc" <%= sort.equals("price_asc") ? "selected" : "" %>>Price (Low→High)</option>
    <option value="price_desc" <%= sort.equals("price_desc") ? "selected" : "" %>>Price (High→Low)</option>
    <option value="type" <%= sort.equals("type") ? "selected" : "" %>>Category</option>
  </select>
  <button type="submit">Apply</button>
</form>

<a href="welcome_user.jsp">← Back to Dashboard</a>
<hr>

<% if (listings.isEmpty()) { %>
<p>No listings found.</p>
<% } else { %>

<table border="1" width="100%">
  <tr>
    <th>Category</th>
    <th>Item</th>
    <th>Status</th>
    <th>Current Price</th>

    <th>Close Time</th>
    <th>Action</th>
  </tr>

  <% for (Map<String,String> item : listings) { %>
  <tr>
    <td><%= item.get("subcat_name") %></td>
    <td><%= item.get("name") %></td>
    <td><%= item.get("status") %></td>
    <td>$<%= item.get("current_price") %></td>

    <td><%= item.get("close_time") %></td>
    <td><a href="auction_detail.jsp?id=<%= item.get("id") %>">View</a></td>
  </tr>
  <% } %>
</table>

<% } %>

</body>
</html>

 