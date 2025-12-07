<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" import="com.cs336.pkg.*, java.sql.*, java.util.*" %>
<%
    // Auth Guard
    Integer userId = (Integer) session.getAttribute("user_id");
    if (userId == null) {
        response.sendRedirect("index.jsp");
        return;
    }

    // Get the subcat_id from the URL (passed by create_auction_select.jsp)
    String subcat_id_str = request.getParameter("subcat_id");
    if (subcat_id_str == null || subcat_id_str.isEmpty()) {
        response.sendRedirect("create_auction_select.jsp");
        return;
    }
    
    // List to hold the fields for this subcategory
    List<String[]> dynamicFields = new ArrayList<>();
    
    ApplicationDB db = new ApplicationDB();
    Connection con = db.getConnection();
    PreparedStatement ps = null;
    ResultSet rs = null;

    try {
        // Query to get all fields for this specific subcategory
        String sql = "SELECT field_id, field_name FROM Field WHERE subcat_id = ?";
        ps = con.prepareStatement(sql);
        ps.setString(1, subcat_id_str);
        rs = ps.executeQuery();
        
        while (rs.next()) {
            dynamicFields.add(new String[]{
                rs.getString("field_id"),
                rs.getString("field_name")
            });
        }

    } catch (Exception e) {
        out.println("Error loading fields: " + e.getMessage());
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
    <title>Create Auction - Step 2</title>
</head>
<body>
    <h2>Create New Auction: Step 2 of 2</h2>
    <p>Please fill out all item details.</p>

    <!-- This form submits ALL data to the processing script -->
    <form action="process_auction.jsp" method="POST">
    
        <!-- Pass the subcat_id along secretly -->
        <input type="hidden" name="subcat_id" value="<%= subcat_id_str %>">
        
        <h3>Standard Item Details</h3>
        <table>
            <tr>
                <td>Item Name:</td>
                <td><input type="text" name="item_name" required></td>
            </tr>
            <tr>
                <td>Description:</td>
                <td><textarea name="description" rows="4" cols="50"></textarea></td>
            </tr>
            <tr>
                <td>Starting Price ($):</td>
                <td><input type="number" name="init_price" min="0.01" step="0.01" required></td>
            </tr>
            <tr>
                <td>Minimum Increment ($):</td>
                <td><input type="number" name="increment" min="0.01" step="0.01" required></td>
            </tr>
            <tr>
                <td>Secret Reserve Price ($):</td>
                <td><input type="number" name="min_price" min="0.01" step="0.01" required></td>
            </tr>
            <tr>
                <td>Auction Close Time:</td>
                <!-- HTML5 datetime input -->
                <td><input type="datetime-local" name="close_time" required></td>
            </tr>
        </table>
        
        <hr>
        
        <!-- *** DYNAMIC FIELDS SECTION *** -->
        <h3>Item-Specific Details</h3>
        <table>
            <%
                // Loop through the fields we queried
                for (String[] field : dynamicFields) {
                    String field_id = field[0];
                    String field_name = field[1];
                    
                    // We use "field_" + field_id as the 'name' to uniquely identify it
                    // e.g., name="field_7"
                    String inputName = "field_" + field_id;
                    
                    out.println("<tr>");
                    out.println("<td>" + field_name + ":</td>");
                    out.println("<td><input type='text' name='" + inputName + "' required></td>");
                    out.println("</tr>");
                }
            %>
        </table>
        
        <br>
        <input type="submit" value="POST MY AUCTION">
    </form>
    <br>
    <a href="create_auction_select.jsp">Back to Subcategory Selection</a>
</body>
</html>