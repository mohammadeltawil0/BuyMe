<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" import="com.cs336.pkg.*, java.sql.*, java.util.*" %>
<%
    // Auth Guard
    Integer userId = (Integer) session.getAttribute("user_id");
    if (userId == null) {
        response.sendRedirect("index.jsp");
        return;
    }
    
    ApplicationDB db = new ApplicationDB();
    Connection con = db.getConnection();
    PreparedStatement ps = null;
    ResultSet rs = null;
    
    List<Map<String,String>> alerts = new ArrayList<>();
    
    try {
        // Get all alerts for this user
        String sql = "SELECT a.field_id, a.field_value, f.field_name, " +
                     "s.name AS subcat_name, c.name AS cat_name " +
                     "FROM Alert a " +
                     "JOIN Field f ON a.field_id = f.field_id " +
                     "JOIN SubCategory s ON f.subcat_id = s.subcat_id " +
                     "JOIN Category c ON s.cat_id = c.cat_id " +
                     "WHERE a.user_id = ? " +
                     "ORDER BY c.name, s.name, f.field_name";
        
        ps = con.prepareStatement(sql);
        ps.setInt(1, userId);
        rs = ps.executeQuery();
        
        while (rs.next()) {
            Map<String,String> alert = new HashMap<>();
            alert.put("field_id", rs.getString("field_id"));
            alert.put("field_value", rs.getString("field_value"));
            alert.put("field_name", rs.getString("field_name"));
            alert.put("subcat_name", rs.getString("subcat_name"));
            alert.put("cat_name", rs.getString("cat_name"));
            alerts.add(alert);
        }
        
    } catch (Exception e) {
        out.println("Error loading alerts: " + e.getMessage());
    } finally {
        if (rs != null) rs.close();
        if (ps != null) ps.close();
        if (con != null) db.closeConnection(con);
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>My Alerts</title>
    <style>
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 10px; border: 1px solid #ccc; text-align: left; }
        th { background-color: #f2f2f2; }
        .success-msg { color: green; background-color: #e6ffe6; padding: 10px; margin: 10px 0; }
    </style>
</head>
<body>
    <h2>My Active Alerts</h2>
    
    <% if (request.getParameter("success") != null) { %>
        <div class="success-msg">✓ Alert created successfully!</div>
    <% } %>
    
    <% if (request.getParameter("deleted") != null) { %>
        <div class="success-msg">✓ Alert deleted successfully!</div>
    <% } %>
    
    <% if (alerts.isEmpty()) { %>
        <p>You have no active alerts.</p>
        <p><a href="create_alert.jsp">Create your first alert</a></p>
    <% } else { %>
        <table>
            <thead>
                <tr>
                    <th>Category</th>
                    <th>Subcategory</th>
                    <th>Field</th>
                    <th>Watching For</th>
                    <th>Action</th>
                </tr>
            </thead>
            <tbody>
                <% for (Map<String,String> alert : alerts) { %>
                    <tr>
                        <td><%= alert.get("cat_name") %></td>
                        <td><%= alert.get("subcat_name") %></td>
                        <td><%= alert.get("field_name") %></td>
                        <td><strong><%= alert.get("field_value") %></strong></td>
                        <td>
                            <form method="POST" action="delete_alert.jsp" style="display:inline;">
                                <input type="hidden" name="field_id" value="<%= alert.get("field_id") %>">
                                <input type="hidden" name="field_value" value="<%= alert.get("field_value") %>">
                                <button type="submit">Delete</button>
                            </form>
                        </td>
                    </tr>
                <% } %>
            </tbody>
        </table>
    <% } %>
    
    <br>
    <a href="create_alert.jsp">+ Create New Alert</a> | 
    <a href="welcome_user.jsp">Back to Dashboard</a>
</body>
</html>