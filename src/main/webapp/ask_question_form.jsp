<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" import="com.cs336.pkg.*" %>
<%
    Integer userId = (Integer) session.getAttribute("user_id");
    if (userId == null) {
        response.sendRedirect("index.jsp");
        return;
    }
%>

<!DOCTYPE html>
<html>
<head>
    <title>Ask a Question</title>
</head>
<body>
    <h2>Ask Customer Support</h2>
    
    <form method="POST" action="ask_question.jsp">
        <label>Your Question:</label><br>
        <textarea name="question" rows="6" cols="60" required></textarea>
        <br><br>
        <button type="submit">Submit Question</button>
    </form>
    
    <br>
    <a href="browse_questions.jsp">Browse Q&A</a> | 
    <a href="welcome_user.jsp">Back</a>
</body>
</html>