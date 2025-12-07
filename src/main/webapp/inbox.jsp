<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" import="com.cs336.pkg.*, java.sql.*, java.util.*, java.text.*" %>
<%
    // Auth Guard
    Integer userId = (Integer) session.getAttribute("user_id");
    if (userId == null) {
        response.sendRedirect("index.jsp");
        return;
    }
    
    ApplicationDB db = new ApplicationDB();
    Connection con = db.getConnection();
    PreparedStatement ps = null;
    ResultSet rs = null;
    
    List<Map<String, String>> messages = new ArrayList<>();
    SimpleDateFormat sdf = new SimpleDateFormat("yyyy-MM-dd HH:mm:ss");

    try {
        // Query to fetch all messages for the current user, ordered by time
        String sql = "SELECT * FROM Inbox WHERE user_id = ? ORDER BY created_at DESC";
        ps = con.prepareStatement(sql);
        ps.setInt(1, userId);
        rs = ps.executeQuery();
        
        while (rs.next()) {
            Map<String, String> msg = new HashMap<>();
            msg.put("id", rs.getString("inbox_id"));
            msg.put("type", rs.getString("message_type")); // OUTBID, AUCTION_OPEN, etc.
            msg.put("auction_id", rs.getString("auction_id")); // Can be null
            msg.put("body", rs.getString("message_body"));
            msg.put("time", sdf.format(rs.getTimestamp("created_at")));
            msg.put("is_read", rs.getBoolean("is_read") ? "Read" : "New");
            messages.add(msg);
        }
        
        // Optional: Mark as read logic could be added here
        
    } catch (Exception e) {
        out.println("Error loading messages: " + e.getMessage());
    } finally {
        if (rs != null) rs.close();
        if (ps != null) ps.close();
        if (con != null) db.closeConnection(con);
    }
%>
<!DOCTYPE html>
<html>
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
    <title>My Inbox</title>
    <style>
        table { width: 100%; border-collapse: collapse; }
        th, td { padding: 10px; border: 1px solid #ccc; text-align: left; }
        th { background-color: #f2f2f2; }
        .msg-new { font-weight: bold; color: #000; background-color: #eef9ff; }
        .msg-read { color: #666; }
        
        /* Badge styles for message types */
        .badge { padding: 3px 8px; border-radius: 4px; font-size: 0.8em; color: white; }
        .badge-outbid { background-color: #d9534f; } /* Red */
        .badge-open { background-color: #5cb85c; }   /* Green */
        .badge-system { background-color: #5bc0de; }  /* Blue */
    </style>
</head>
<body>
    <h2>My Alerts / Messages</h2>
    <a href="welcome_user.jsp">← Back to Dashboard</a>
    <hr>
    
    <% if (messages.isEmpty()) { %>
        <p>You have no messages.</p>
    <% } else { %>
        <table>
            <thead>
                <tr>
                    <th>Time</th>
                    <th>Type</th>
                    <th>Message</th>
                    <th>Action</th>
                </tr>
            </thead>
            <tbody>
                <% for (Map<String, String> msg : messages) { 
                   String rowClass = msg.get("is_read").equals("New") ? "msg-new" : "msg-read";
                   String type = msg.get("type");
                   String badgeClass = "badge-system"; // default
                   
                   if ("OUTBID".equals(type)) badgeClass = "badge-outbid";
                   else if ("AUCTION_OPEN".equals(type)) badgeClass = "badge-open";
                %>
                    <tr class="<%= rowClass %>">
                        <td style="width: 160px;"><%= msg.get("time") %></td>
                        
                        <td style="width: 100px;">
                            <span class="badge <%= badgeClass %>"><%= type %></span>
                        </td>
                        
                        <td>
                            <%= msg.get("body") %>
                        </td>
                        
                        <td style="width: 120px;">
                            <% 
                                // If auction_id exists (not null/0), show a link
                                String aucId = msg.get("auction_id");
                                if (aucId != null && !aucId.equals("0")) { 
                            %>
                                <a href="auction_detail.jsp?id=<%= aucId %>">View Auction</a>
                            <% } %>
                        </td>
                    </tr>
                <% } %>
            </tbody>
        </table>
    <% } %>
</body>
</html>