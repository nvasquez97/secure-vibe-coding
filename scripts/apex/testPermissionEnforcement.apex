Boolean hasPerm = RiskAssessmentController.hasManualAssessmentPermission();

System.debug('=== Permission Check for Running User ===');
System.debug('User: ' + UserInfo.getUserName());
System.debug('Has Can_Request_Manual_Assessment: ' + hasPerm);

if (!hasPerm) {
    throw new IllegalArgumentException(
        'Admin user does not have Can_Request_Manual_Assessment permission. ' +
        'Ensure Risk_Advisor_Manager permission set is assigned to the running user.'
    );
}

System.debug('SUCCESS: Permission enforcement check passed.');
