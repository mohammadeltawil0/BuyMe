<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>Login / Register</title>
</head>
<body>

    <!-- 1. Login Form -->
    <h2>Login</h2>
    
    <% 
        // Check for "login failed" error message (from checkLogin.jsp)
        String loginError = request.getParameter("error");
        if (loginError != null && loginError.equals("1")) {
            out.println("<p style='color:red;'>Invalid Email or Password!</p>");
        }
    
        // Check for "registration success" message (from register.jsp)
        String regSuccess = request.getParameter("reg_success");
        if (regSuccess != null && regSuccess.equals("1")) {
            out.println("<p style='color:green;'>Account created successfully! Please log in.</p>");
        }

        // Check for "registration failed" error message (from register.jsp)
        String regError = request.getParameter("reg_error");
        if (regError != null) {
            out.println("<p style='color:red;'>Registration failed! This Email is already in use.</p>");
        }
    %>
    
    <!-- Login form: Submits to checkLogin.jsp -->
    <form method="post" action="checkLogin.jsp">
        <table>
            <tr>
                <td>Email (for login):</td>
                <td><input type="text" name="email" required></td>
            </tr>
            <tr>
                <td>Password:</td>
                <td><input type="password" name="password" required></td>
            </tr>
        </table>
        <input type="submit" value="Login">
    </form>

    <hr>

    <!-- 2. Register Form -->
    <h2>Register New Account</h2>
    <p>(For 'user' accounts only)</p>
    
    <!-- Registration form: Submits to register.jsp -->
    <form method="post" action="register.jsp">
        <table>
            <tr>
                <td>Your Email (must be unique):</td>
                <td><input type="email" name="email" required></td>
            </tr>
            <tr>
                <!-- *** MODIFIED LABEL *** -->
                <td>Your Display Name (can be a duplicate):</td>
                <td><input type="text" name="username" required></td>
            </tr>
            <tr>
                <td>Set Password:</td>
                <td><input type="password" name="password" required></td>
            </tr>
        </table>
        <input type="submit" value="Register">
    </form>

</body>
</html>