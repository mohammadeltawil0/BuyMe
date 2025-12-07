<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" import="com.cs336.pkg.*"%>
<%@ page import="java.io.*,java.util.*,java.sql.*"%>
<%@ page import="javax.servlet.http.*,javax.servlet.*"%>

<%
    // 1. Get all parameters from the registration form
    String email = request.getParameter("email");
    String username = request.getParameter("username");
    String password = request.getParameter("password");
    
    // This is your requirement: hard-code the type as 'user'
    String usertype = "user"; 

    ApplicationDB db = new ApplicationDB();
    Connection con = db.getConnection();
    
    // We use a PreparedStatement to prevent SQL injection
    PreparedStatement ps = null;

    try {
        // 2. Prepare the SQL INSERT statement
        // We are using your updated schema field names (email, username, password, usertype)
        String query = "INSERT INTO User (email, username, password, usertype) VALUES (?, ?, ?, ?)";
        
        ps = con.prepareStatement(query);
        ps.setString(1, email);
        ps.setString(2, username);
        ps.setString(3, password);
        ps.setString(4, usertype); // 'user' type
        
        // 3. Execute the update
        int rowsAffected = ps.executeUpdate();
        
        if (rowsAffected > 0) {
            // 4a. Success: Redirect back to the login page with a success message
            response.sendRedirect("index.jsp?reg_success=1");
        } else {
            // 4b. Failure (rare, but just in case)
            response.sendRedirect("index.jsp?reg_error=1");
        }
        
    } catch (SQLException e) {
        // 4c. Catch SQL errors (most common is UNIQUE constraint violation)
        response.sendRedirect("index.jsp?reg_error=1");
    } catch (Exception e) {
        // Catch all other potential exceptions
        response.sendRedirect("index.jsp?reg_error=1");
    } finally {
        // 5. Ensure resources are closed
        if (ps != null) {
            try {
                ps.close();
            } catch (SQLException e) { /* ignore */ }
        }
        if (con != null) {
            db.closeConnection(con);
        }
    }
%>