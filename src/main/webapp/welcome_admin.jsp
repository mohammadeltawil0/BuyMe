<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%
    // Auth Guard: Check if user is logged in AND is an 'admin'
    Integer userId = (Integer) session.getAttribute("user_id");
	String username = (String) session.getAttribute("username");
    String usertype = (String) session.getAttribute("usertype");
    if (userId == null || username == null || usertype == null || !usertype.equals("admin")) {
        response.sendRedirect("index.jsp");
        return;
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>Admin Dashboard</title>
</head>
<body>
    <h2>Welcome, Admin <%= username %>!</h2>
    <p>This is the main dashboard for administrators.</p>
    <h3>Admin Abilities</h3>
    <ul>
    	<li><a href="create_rep.jsp">Create Customer Rep Account</a></li>
        <li><a href="sales_report.jsp">View Sales Reports</a></li>
    </ul>
    <a href="logout.jsp">Logout</a>
</body>
</html>