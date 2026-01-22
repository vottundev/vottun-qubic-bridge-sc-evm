diff --git a/QubicBridge.sol b/QubicBridge.sol
index 0000000..1111111 100644
--- a/QubicBridge.sol
+++ b/QubicBridge.sol
@@
     error AlreadyManager();
     error AlreadyOperator();
+    error CannotWithdrawBridgeToken();
+    error MustBePaused();

@@ function addAdmin(address newAdmin) external onlyProposal returns (bool) {
         if (newAdmin == address(0)) {
             revert InvalidAddress();
         }
+        if (hasRole(DEFAULT_ADMIN_ROLE, newAdmin)) {
+            revert AlreadyAdmin();
+        }

@@ function addManager(address newManager) external onlyProposal returns (bool) {
         if (newManager == address(0)) {
             revert InvalidAddress();
         }
+        if (hasRole(MANAGER_ROLE, newManager)) {
+            revert AlreadyManager();
+        }

@@ function addOperator(address newOperator) external onlyProposal returns (bool) {
         if (newOperator == address(0)) {
             revert InvalidAddress();
         }
+        if (hasRole(OPERATOR_ROLE, newOperator)) {
+            revert AlreadyOperator();
+        }

@@ function confirmOrder(uint256 orderId, uint256 feePct)
-        PullOrder memory order = pullOrders[orderId];
+        PullOrder storage order = pullOrders[orderId];

@@ function revertOrder(uint256 orderId, uint256 feePct)
-        PullOrder memory order = pullOrders[orderId];
+        PullOrder storage order = pullOrders[orderId];

-        // Delete the order
-        delete pullOrders[orderId];
-
         uint256 fee = getTransferFee(amount, feePct);
         uint256 amountAfterFee = amount - fee;

@@
         QubicToken(token).transfer(order.originAccount, amountAfterFee);

+        // Delete the order AFTER external calls
+        delete pullOrders[orderId];

@@ function emergencyTokenWithdraw(
     function emergencyTokenWithdraw(
         address tokenAddress,
         address recipient,
         uint256 amount
     ) external onlyProposal {
+        if (!paused()) {
+            revert MustBePaused();
+        }
         if (recipient == address(0)) {
             revert InvalidAddress();
         }
+        if (tokenAddress == token) {
+            revert CannotWithdrawBridgeToken();
+        }

@@ function emergencyEtherWithdraw(address recipient) external onlyProposal {
     function emergencyEtherWithdraw(address recipient) external onlyProposal {
+        if (!paused()) {
+            revert MustBePaused();
+        }
         if (recipient == address(0)) {
             revert InvalidAddress();
         }
