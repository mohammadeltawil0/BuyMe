<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" import="com.cs336.pkg.*, java.sql.*, java.util.*" %>
<%
    // Auth Guard: User must be logged in.
    Integer userId = (Integer) session.getAttribute("user_id");
    if (userId == null) {
        response.sendRedirect("index.jsp");
        return;
    }
    
    // Database connection
    ApplicationDB db = new ApplicationDB();
    Connection con = db.getConnection();
    Statement stmt = null;
    ResultSet rs = null;
    
    // We will store categories and their fields in a Map
    // Key: Category + Subcategory Name (String)
    // Value: List of Fields (List<Map<String,String>>)
    Map<String, List<Map<String,String>>> categoryFields = new LinkedHashMap<>();

    try {
        // Query to get subcategories and all of their items, ordered
        String sql = "SELECT c.name AS category_name, s.name AS subcategory_name, " +
	                 "f.field_id, f.field_name " +
	                 "FROM Category c " +
	                 "JOIN SubCategory s ON c.cat_id = s.cat_id " +
	                 "JOIN Field f ON s.subcat_id = f.subcat_id " +
	                 "ORDER BY c.name, s.name, f.field_name";
        stmt = con.createStatement();
        rs = stmt.executeQuery(sql);

        while (rs.next()) {
        	  String categoryName = rs.getString("category_name");
              String subCatName = rs.getString("subcategory_name");
              String fieldId = rs.getString("field_id");
              String fieldName = rs.getString("field_name");
              
              // Create a combined key like "Electronics > Smartphones"
              String categoryKey = categoryName + " > " + subCatName;
              
              // If the category is not in the map, add it
              categoryFields.putIfAbsent(categoryKey, new ArrayList<>());
              
              Map<String, String> field = new HashMap<>();
              field.put("field_id", fieldId);
              field.put("field_name", fieldName);
              // Add the subcategory to this category's list
              categoryFields.get(categoryKey).add(field);
        }

    } catch (Exception e) {
        out.println("Error loading categories: " + e.getMessage());
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
    <title>Set Item Alerts</title>
    <style>
        .alert-form { max-width: 600px; margin: 20px auto; padding: 20px; border: 1px solid #ccc; }
        select, input { width: 100%; padding: 8px; margin: 5px 0; }
    </style>
</head>
<body>
    <h2>Set Alert for Items</h2>
    <p>Get notified when items matching your criteria are posted!</p>
    
    <% if (request.getParameter("error") != null) { %>
        <p style="color: red;">Error: Alert already exists!!</p>
    <% } %>
    
    <div class="alert-form">
        <form method="POST" action="process_alert.jsp">
            <label>Select Item Characteristic:</label>
            <select name="field_id" required>
                <option value="">-- Choose Field --</option>
                <% 
                    // Loop through each category
                    for (Map.Entry<String, List<Map<String,String>>> entry : categoryFields.entrySet()) { 
                %>
                    <optgroup label="<%= entry.getKey() %>">
                        <% 
                            // Loop through fields in this category
                            for (Map<String,String> field : entry.getValue()) { 
                        %>
                            <option value="<%= field.get("field_id") %>">
                                <%= field.get("field_name") %>
                            </option>
                        <% } %>
                    </optgroup>
                <% } %>
            </select>
            
            <label>Value to Watch For:</label>
            <input type="text" name="field_value" placeholder="e.g., 128GB, Blue, etc." required>
            
            <br><br>
            <button type="submit">Create Alert</button>
        </form>
    </div>
    
    <hr>
    <a href="browse_alerts.jsp">View My Alerts</a> | 
    <a href="welcome_user.jsp">Back to Dashboard</a>
</body>
</html>