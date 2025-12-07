<%@ page language="java" contentType="text/html; charset=UTF-8"
   pageEncoding="UTF-8" import="com.cs336.pkg.*, java.sql.*, java.util.*" %>
<%
   // Auth Guard: User must be logged in to post
   Integer sellerId = (Integer) session.getAttribute("user_id");
   if (sellerId == null) {
       response.sendRedirect("index.jsp");
       return;
   }
   // Get all standard parameters
   String subcat_id = request.getParameter("subcat_id");
   String item_name = request.getParameter("item_name");
   String description = request.getParameter("description");
   String init_price = request.getParameter("init_price");
   String increment = request.getParameter("increment");
   String min_price = request.getParameter("min_price");
   String close_time = request.getParameter("close_time"); // Will be in "YYYY-MM-DDThh:mm" format
   ApplicationDB db = new ApplicationDB();
   Connection con = db.getConnection();
   PreparedStatement psAuction = null;
   PreparedStatement psFieldsQuery = null;
   PreparedStatement psFieldInsert = null;
   ResultSet rsGeneratedKeys = null;
   ResultSet rsFields = null;
  
   int newAuctionId = -1; // We'll get this ID after the first insert
   try {
       // *** START TRANSACTION ***
       // We are writing to two tables, so we must use a transaction
       // to ensure data integrity.
       con.setAutoCommit(false);
       // --- 1. INSERT into Auction Table ---
      
       // Note: is_removed defaults to FALSE, so we don't need to set it
       String sqlAuction = "INSERT INTO Auction (seller_id, subcat_id, item_name, description, init_price, increment, min_price, close_time) " +
                           "VALUES (?, ?, ?, ?, ?, ?, ?, ?)";
      
       psAuction = con.prepareStatement(sqlAuction, Statement.RETURN_GENERATED_KEYS);
       psAuction.setInt(1, sellerId);
       psAuction.setString(2, subcat_id);
       psAuction.setString(3, item_name);
       psAuction.setString(4, description);
       psAuction.setString(5, init_price);
       psAuction.setString(6, increment);
       psAuction.setString(7, min_price);
       psAuction.setString(8, close_time); // MySQL can parse this datetime-local format
      
       int rowsAffected = psAuction.executeUpdate();
       if (rowsAffected == 0) {
           throw new SQLException("Creating auction failed, no rows affected.");
       }
       // --- 2. Get the new auction_id that was just created ---
       rsGeneratedKeys = psAuction.getGeneratedKeys();
       if (rsGeneratedKeys.next()) {
           newAuctionId = rsGeneratedKeys.getInt(1);
       } else {
           throw new SQLException("Creating auction failed, no ID obtained.");
       }
       // --- 3. INSERT into Auction_Field Table ---
      
       // First, we need to find out WHICH fields we need to read
       String sqlFields = "SELECT field_id FROM Field WHERE subcat_id = ?";
       psFieldsQuery = con.prepareStatement(sqlFields);
       psFieldsQuery.setString(1, subcat_id);
       rsFields = psFieldsQuery.executeQuery();
       // Prepare the batch insert for Auction_Field
       String sqlFieldInsert = "INSERT INTO Auction_Field (auction_id, field_id, field_value) VALUES (?, ?, ?)";
       psFieldInsert = con.prepareStatement(sqlFieldInsert);
       // Loop through all the fields that *should* exist for this subcategory
       while (rsFields.next()) {
           String field_id = rsFields.getString("field_id");
          
           // Construct the name used in the form, e.g., "field_7"
           String paramName = "field_" + field_id;
          
           // Get the value from the form
           String paramValue = request.getParameter(paramName);
          
           // Add this insert to our batch
           psFieldInsert.setInt(1, newAuctionId);
           psFieldInsert.setString(2, field_id);
           psFieldInsert.setString(3, paramValue);
           psFieldInsert.addBatch();
       }
      
       // Execute the batch insert for all fields
       psFieldInsert.executeBatch();
       		
   	// Mohammad Alert Implementation
      	// Check if any users have this new auction as an alert
      	try {
      		String sqlAlerts =
      			    "SELECT DISTINCT a.user_id, f.field_name, af.field_value " +
      			    "FROM Alert a " +
      			    "JOIN Auction_Field af ON a.field_id = af.field_id AND a.field_value = af.field_value " +
      			    "JOIN User u ON a.user_id = u.user_id " +
      			    "JOIN Field f ON a.field_id = f.field_id " +
      			    "WHERE af.auction_id = ?; ";
      							
      		PreparedStatement psAlert = con.prepareStatement(sqlAlerts);
      		psAlert.setInt(1, newAuctionId);
      		ResultSet rsAlert = psAlert.executeQuery();
      		
      		// Iterate through all users to find a matching alert and notify them
      		while (rsAlert.next()) {
      			int alertUserId = rsAlert.getInt("user_id");
      			String fieldName = rsAlert.getString("field_name");
      			String fieldValue = rsAlert.getString("field_value");
      			
      			// Create notification message
      			String notifMsg = "A new auction is matching your alert: " + item_name + " with " + fieldName + " = " + fieldValue + " is now open!";
      			
      			// Put notification in user's inbox
      			String sqlNotif = "INSERT INTO Inbox (user_id, auction_id, message_type, message_body) VALUES (?, ?, 'AUCTION_OPEN', ?)";
      			
      			PreparedStatement psNotif = con.prepareStatement(sqlNotif);
      			psNotif.setInt(1, alertUserId);
      			psNotif.setInt(2, newAuctionId);
      			psNotif.setString(3, notifMsg);
      			psNotif.executeUpdate();
      			psNotif.close();
      		}
      		
      		rsAlert.close();
      		psAlert.close();
      	
      	}
   	
   	catch (Exception e) {
   		System.out.println("Alert notification error: " + e.getMessage());
   	}
   	// Mohammad End of implementation for notif
       		
       		
       // --- 4. If all inserts are successful, COMMIT the transaction ---
       con.commit();
      
       		
     
       // --- 5. Redirect to success page ---
       // (We'll create this page later, for now, just go to welcome)
       response.sendRedirect("welcome_user.jsp?auction_success=1");
   } catch (Exception e) {
       // If *anything* goes wrong, rollback all changes
       if (con != null) {
           try {
               con.rollback();
           } catch (SQLException ex) {
               ex.printStackTrace();
           }
       }
       out.println("Error creating auction: " + e.getMessage());
       response.sendRedirect("welcome_user.jsp?auction_fail=1");
      
   } finally {
       // --- 6. Close all resources ---
       if (rsGeneratedKeys != null) rsGeneratedKeys.close();
       if (rsFields != null) rsFields.close();
       if (psAuction != null) psAuction.close();
       if (psFieldsQuery != null) psFieldsQuery.close();
       if (psFieldInsert != null) psFieldInsert.close();
       if (con != null) {
           try {
               con.setAutoCommit(true); // Reset to default
           } catch (SQLException e) {}
           db.closeConnection(con);
       }
   }
%>