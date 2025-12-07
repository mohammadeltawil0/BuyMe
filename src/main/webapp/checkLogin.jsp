<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" import="com.cs336.pkg.*"%>
<%@ page import="java.io.*,java.util.*,java.sql.*"%>
<%@ page import="javax.servlet.http.*,javax.servlet.*"%>

<%
    // Get form parameters from index.jsp
    // We assume the form is sending 'email' for login, as 'username' is not unique
    String email = request.getParameter("email");
    String password = request.getParameter("password");
    
    // Get database connection from our ApplicationDB class
    ApplicationDB db = new ApplicationDB();
    Connection con = db.getConnection();
    
    try {
        // Create a PreparedStatement to prevent SQL injection
        // We select all the data we need to store in the session
        String query = "SELECT user_id, username, usertype FROM User WHERE email = ? AND password = ?";
        
        PreparedStatement ps = con.prepareStatement(query);
        ps.setString(1, email);
        ps.setString(2, password);
        
        // Execute the query
        ResultSet rs = ps.executeQuery();
        
        // Check if a matching user was found
        if (rs.next()) {
            // Login successful
            
            // 1. Get all the necessary data from the result set
            int userId = rs.getInt("user_id");
            String username = rs.getString("username"); // The non-unique name for display
            String usertype = rs.getString("usertype");
            
            // 2. Store all data in the session for future use
            //    'user_id' is for all database operations (bidding, posting, etc.)
            //    'username' is for display (e.g., "Welcome, John!")
            //    'usertype' is for authorization (e.g., is this user an admin?)
            session.setAttribute("user_id", userId);
            session.setAttribute("username", username);
            session.setAttribute("usertype", usertype);
            
            // 3. Redirect the user to the correct dashboard based on their usertype
            if (usertype.equals("admin")) {
                response.sendRedirect("welcome_admin.jsp");
            } else if (usertype.equals("cust_rep")) {
                response.sendRedirect("welcome_rep.jsp");
            } else { // The type is "user"
                response.sendRedirect("welcome_user.jsp");
            }
            
        } else {
            // Login failed - no user matched the email/password combination
            // Redirect back to the login page with an error flag
            response.sendRedirect("index.jsp?error=1");
        }
        
        // Close the result set and statement
        rs.close();
        ps.close();
        
    } catch (Exception e) {
        // Handle any database or other exceptions
        out.println("An error occurred during the login process: " + e.getMessage());
    } finally {
        // Always close the connection in the finally block
        if (con != null) {
            db.closeConnection(con);
        }
    }
%>