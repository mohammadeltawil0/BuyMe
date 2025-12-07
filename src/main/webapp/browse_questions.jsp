<%@ page language="java" contentType="text/html; charset=UTF-8"
    pageEncoding="UTF-8" import="com.cs336.pkg.*, java.sql.*, java.util.*" %>
<%
    // Auth Guard
    Integer userId = (Integer) session.getAttribute("user_id");
    if (userId == null) {
        response.sendRedirect("index.jsp");
        return;
    }
    
    String keywordInput = request.getParameter("keyword");
    if (keywordInput == null) keywordInput = "";
    
    ApplicationDB db = new ApplicationDB();
    Connection con = db.getConnection();
    PreparedStatement ps = null;
    ResultSet rs = null;
    
    List<Map<String,String>> questions = new ArrayList<>();
    
    try {
        // Get all alerts for this user
        String sql = "SELECT q.qid, q.q_desc, q.answer, u.username AS asker " +
                     "FROM Question q " +
                     "JOIN User u ON q.user_id = u.user_id ";
        
        if (!keywordInput.isEmpty()) {
        	sql += "WHERE q.q_desc LIKE ? OR q.answer LIKE ?";
        }
        
        sql += "ORDER BY q.qid DESC";
        
        ps = con.prepareStatement(sql);
        if (!keywordInput.isEmpty()) {
            String keyword = "%" + keywordInput + "%";
            ps.setString(1, keyword);
            ps.setString(2, keyword);
        }
        rs = ps.executeQuery();
        
        while (rs.next()) {
            Map<String,String> q_and_a = new HashMap<>();
            q_and_a.put("qid", rs.getString("qid"));
            q_and_a.put("question", rs.getString("q_desc"));
            q_and_a.put("answer", rs.getString("answer"));
            q_and_a.put("asker", rs.getString("asker"));
            questions.add(q_and_a);
        }
        
    } catch (Exception e) {
        out.println("Error loading questions: " + e.getMessage());
    } finally {
        if (rs != null) rs.close();
        if (ps != null) ps.close();
        if (con != null) db.closeConnection(con);
    }
%>
<!DOCTYPE html>
<html>
<head>
    <title>Q&A Forum</title>
    <style>
        .qa-item { border: 1px solid #ccc; padding: 15px; margin: 10px 0; }
        .question { font-weight: bold; color: #333; }
        .answer { margin-top: 10px; padding-left: 20px; color: #0066cc; }
        .unanswered { color: #999; font-style: italic; }
    </style>
</head>
<body>
    <h2>Customer Support Q&A</h2>
    
    <% if (request.getParameter("submitted") != null) { %>
        <p style="color: green;">Your question has been submitted!</p>
    <% } %>
    
    <form method="GET">
        <input type="text" name="keyword" placeholder="Search questions..." 
               value="<%= keywordInput %>" size="40">
        <button type="submit">Search</button>
    </form>
    
    <hr>
    
    <% if (questions.isEmpty()) { %>
        <p>No questions found.</p>
    <% } else { %>
        <% for (Map<String,String> qa : questions) { %>
            <div class="qa-item">
                <div class="question">
                    Q: <%= qa.get("question") %>
                    <small>(asked by <%= qa.get("asker") %>)</small>
                </div>
                
                <% if (qa.get("answer") != null) { %>
                    <div class="answer">
                        <strong>A:</strong> <%= qa.get("answer") %>
                    </div>
                <% } else { %>
                    <div class="unanswered">
                        Waiting for customer rep to answer...
                    </div>
                <% } %>
            </div>
        <% } %>
    <% } %>
    
    <br>
    <a href="ask_question_form.jsp">+ Ask New Question</a> | 
    <a href="welcome_user.jsp">Back</a>
</body>
</html>