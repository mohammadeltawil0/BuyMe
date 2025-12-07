<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<%
	// Auth Guard: User must be logged in.
	Integer userId = (Integer) session.getAttribute("user_id");
	String usertype = (String) session.getAttribute("usertype");

	if (userId == null || !usertype.equals("admin")) {
	    response.sendRedirect("index.jsp");
	    return;
	}

%>



<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<title>Create New Customer Representative</title>
</head>
<body>
	<h2>Create New Customer Representative</h2>
	<% if (request.getParameter("success") != null) { %>
        <p style="color: green;">Customer Rep account created successfully!</p>
    <% } %>
    
    <% if (request.getParameter("error") != null) { %>
        <p style="color: red;">Error: Email already exists!</p>
    <% } %>
    
    <form method="POST" action="process_rep.jsp">
        <table>
            <tr>
                <td>Email:</td>
                <td><input type="email" name="email" required></td>
            </tr>
            <tr>
                <td>Username:</td>
                <td><input type="text" name="username" required></td>
            </tr>
            <tr>
                <td>Password:</td>
                <td><input type="password" name="password" required></td>
            </tr>
        </table>
        <br>
        <button type="submit">Create Rep Account</button>
    </form>
    
    <br>
    <a href="welcome_admin.jsp">Back to Dashboard</a>
</body>
</html>