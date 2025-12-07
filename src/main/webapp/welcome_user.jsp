<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" import="com.cs336.pkg.*, java.sql.*, java.util.*" %>
<%
    // Auth Guard: Check if user is logged in AND is a 'user'
    Integer userId = (Integer) session.getAttribute("user_id");
    String usertype = (String) session.getAttribute("usertype");
    String username = (String) session.getAttribute("username");

    if (userId == null || usertype == null || !usertype.equals("user")) {
        response.sendRedirect("index.jsp");
        return;
    }
    
    // --- NEW: Fetch Unread Message Count ---
    int unreadCount = 0;
    ApplicationDB db = new ApplicationDB();
    Connection con = db.getConnection();
    PreparedStatement ps = null;
    ResultSet rs = null;
    
    try {
        // Count messages where is_read is FALSE
        String sqlCount = "SELECT COUNT(*) FROM Inbox WHERE user_id = ? AND is_read = FALSE";
        ps = con.prepareStatement(sqlCount);
        ps.setInt(1, userId);
        rs = ps.executeQuery();
        if (rs.next()) {
            unreadCount = rs.getInt(1);
        }
    } catch (Exception e) {
        // Fail silently for count, just show 0
        e.printStackTrace();
    } finally {
        if (rs != null) try { rs.close(); } catch (SQLException e) {}
        if (ps != null) try { ps.close(); } catch (SQLException e) {}
        if (con != null) db.closeConnection(con);
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>Welcome User</title>
    <style>
        /* Simple badge style for unread count */
        .badge-red {
            background-color: red;
            color: white;
            padding: 3px 8px;
            border-radius: 10px;
            font-weight: bold;
            font-size: 0.8em;
            vertical-align: middle;
        }
    </style>
</head>
<body>
    <h2>Welcome, <%= username %>!</h2>

    <%
        // Check for auction success/failure messages
        String auctionSuccess = request.getParameter("auction_success");
        if (auctionSuccess != null && auctionSuccess.equals("1")) {
            out.println("<p style='color:green; font-weight:bold;'>Your auction was created successfully!</p>");
        }

        String auctionFail = request.getParameter("auction_fail");
        if (auctionFail != null) {
            out.println("<p style='color:red; font-weight:bold;'>Error: Your auction could not be created. Please try again.</p>");
        }
    %>

    <p>This is the dashboard for regular users.</p>
    
    <!-- *** NEW: ALERTS SECTION *** -->
    <hr>
    <h3>Alerts & Notifications</h3>
    <a href="inbox.jsp" style="font-size: 1.1em;">
        Go to My Inbox
        <% if (unreadCount > 0) { %>
            <span class="badge-red"><%= unreadCount %> NEW</span>
        <% } %>
    </a>
    
    <br>
    <a href="create_alert.jsp">Create a New Alert</a>
    <br>
    <a href="browse_alerts.jsp">View/Manage My Alerts</a>
    <br>

    <!-- *** EXISTING: MY AUCTIONS *** -->
    <hr>
    <h3>My Auctions</h3>
    <a href="create_auction_select.jsp">Create a New Auction</a>
    <br>
    <a href="my_listings.jsp">View/Manage My Listings (All Statuses)</a>
    <br>
    <a href="bid_history.jsp">View/Manage My bid history </a>
    <br>
    
    <!-- *** EXISTING: MARKETPLACE *** -->
    <hr>
    <h3>Marketplace</h3>
    <a href="browse.jsp">Browse All Auctions</a>
    <br>
    <hr>

    <a href="logout.jsp">Logout</a>
</body>
</html> 