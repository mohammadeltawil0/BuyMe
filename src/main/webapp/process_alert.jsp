<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" import="com.cs336.pkg.*, java.sql.*" %>

<%
    // Auth Guard
    Integer userId = (Integer) session.getAttribute("user_id");
    if (userId == null) {
        response.sendRedirect("index.jsp");
        return;
    }
    
    String fieldId = request.getParameter("field_id");
    String fieldValue = request.getParameter("field_value");
    
    ApplicationDB db = new ApplicationDB();
    Connection con = db.getConnection();
    PreparedStatement ps = null;
    
    try {
    	String sql = "INSERT INTO Alert (user_id, field_id, field_value) VALUES (?, ?, ?)";
    	
    	ps = con.prepareStatement(sql);
    	ps.setInt(1, userId);
        ps.setString(2, fieldId);
        ps.setString(3, fieldValue);
        
        ps.executeUpdate();
        
        response.sendRedirect("browse_alerts.jsp?success=1");

    }
    catch (SQLException e) {
        // If we get here, it's probably because the alert already exists
        // (duplicate key error due to PRIMARY KEY constraint)
        response.sendRedirect("create_alert.jsp?error=duplicate");
    } 
   finally {
	    if (ps != null) ps.close();
	    if (con != null) db.closeConnection(con);
	}

%>
