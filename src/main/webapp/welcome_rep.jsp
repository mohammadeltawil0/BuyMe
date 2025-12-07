<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" import="com.cs336.pkg.*, java.sql.*, java.util.*" %>
<%
    // Auth Guard: Check if user is logged in AND is a 'cust_rep'
    Integer userId = (Integer) session.getAttribute("user_id");
	String username = (String) session.getAttribute("username");
    String usertype = (String) session.getAttribute("usertype");
    if (userId == null || username == null || usertype == null || !usertype.equals("cust_rep")) {
        response.sendRedirect("index.jsp");
        return;
    }
    
    ApplicationDB db = new ApplicationDB();
    Connection con = db.getConnection();
    
    int numQuestionsUnanswered = 0;
    
    try {
    	String sql = "SELECT COUNT(*) FROM Question WHERE answer IS NULL";
    	PreparedStatement ps = con.prepareStatement(sql);
    	ResultSet rs = ps.executeQuery();
    	if (rs.next()) numQuestionsUnanswered = rs.getInt(1);
    	rs.close();
    	ps.close();
    	
    }
    catch (Exception e) {
        out.println("Error loading fields: " + e.getMessage());
    }
    finally {
    	
    	db.closeConnection(con);
 
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>Customer Rep Dashboard</title>
</head>
<body>
    <h2>Welcome, Customer Rep <%= username %>!</h2>
    <p>This is the control panel for customer representatives.</p>
    
    <a href="logout.jsp">Logout</a>
</body>
</html>