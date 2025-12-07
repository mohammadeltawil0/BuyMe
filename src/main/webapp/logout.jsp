<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="ISO-8859-1"%>
<%
    session.invalidate();
    response.sendRedirect("index.jsp");
%>