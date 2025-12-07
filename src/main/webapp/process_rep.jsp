<%@ page language="java" contentType="text/html; charset=UTF-8"
   pageEncoding="UTF-8" import="com.cs336.pkg.*, java.sql.*" %>
<%
   Integer userId = (Integer) session.getAttribute("user_id");
   String usertype = (String) session.getAttribute("usertype");
  
   if (userId == null || !usertype.equals("admin")) {
       response.sendRedirect("index.jsp");
       return;
   }
  
   String email = request.getParameter("email");
   String username = request.getParameter("username");
   String password = request.getParameter("password");
  
   ApplicationDB db = new ApplicationDB();
   Connection con = db.getConnection();
  
   try {
       String sql = "INSERT INTO User (email, username, password, usertype) VALUES (?, ?, ?, 'cust_rep')";
       PreparedStatement ps = con.prepareStatement(sql);
       ps.setString(1, email);
       ps.setString(2, username);
       ps.setString(3, password);
      
       ps.executeUpdate();
       ps.close();
      
       response.sendRedirect("create_rep.jsp?success=1");
      
   } catch (SQLException e) {
       response.sendRedirect("create_rep.jsp?error=duplicate");
   } finally {
       db.closeConnection(con);
   }
%>
