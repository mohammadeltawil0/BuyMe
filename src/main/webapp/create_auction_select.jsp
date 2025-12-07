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
    
    // We will store categories and their subcategories in a Map
    // Key: Category Name (String)
    // Value: List of SubCategories (List<String[]>)
    Map<String, List<String[]>> categoriesMap = new LinkedHashMap<>();

    try {
        // Query to get all categories and subcategories, ordered
        String sql = "SELECT c.name AS category_name, s.subcat_id, s.name AS subcategory_name " +
                     "FROM Category c JOIN SubCategory s ON c.cat_id = s.cat_id " +
                     "ORDER BY c.name, s.name";
        stmt = con.createStatement();
        rs = stmt.executeQuery(sql);

        while (rs.next()) {
            String categoryName = rs.getString("category_name");
            String subCatId = rs.getString("subcat_id");
            String subCatName = rs.getString("subcategory_name");
            
            // If the category is not in the map, add it
            categoriesMap.putIfAbsent(categoryName, new ArrayList<>());
            
            // Add the subcategory to this category's list
            categoriesMap.get(categoryName).add(new String[]{subCatId, subCatName});
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
    <title>Create Auction - Step 1</title>
</head>
<body>
    <h2>Create New Auction: Step 1 of 2</h2>
    <p>Please select the subcategory for the item you wish to sell.</p>

    <!-- This form submits the chosen subcat_id to Step 2 -->
    <form action="create_auction_form.jsp" method="GET">
        <label for="subcat_id">Item SubCategory:</label>
        <select name="subcat_id" id="subcat_id" required>
            <option value="">-- Please Select --</option>
            <%
                // Loop through the Map to create <optgroup> for each category
                for (String categoryName : categoriesMap.keySet()) {
                    out.println("<optgroup label='" + categoryName + "'>");
                    
                    // Loop through the subcategories for this category
                    for (String[] subCat : categoriesMap.get(categoryName)) {
                        out.println("<option value='" + subCat[0] + "'>" + subCat[1] + "</option>");
                    }
                    out.println("</optgroup>");
                }
            %>
        </select>
        
        <br><br>
        <input type="submit" value="Next Step (Fill Form)">
    </form>
    <br>
    <a href="welcome_user.jsp">Cancel</a>
</body>
</html>