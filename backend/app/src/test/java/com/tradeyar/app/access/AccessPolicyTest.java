package com.tradeyar.app.access;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class AccessPolicyTest {
    @Test void rolesAreResearchOnly() {
        assertTrue(AccessService.permissions("ADMIN").contains("USER_MANAGE"));
        assertFalse(AccessService.permissions("ANALYST").contains("USER_MANAGE"));
        assertFalse(AccessService.permissions("VIEWER").contains("RESEARCH_RUN"));
        for(String role : new String[]{"ADMIN","RESEARCH_MANAGER","ANALYST","VIEWER"}){
            assertFalse(AccessService.permissions(role).contains("LIVE_ORDER"));
        }
    }
    @Test void passwordHashIsSaltedAndVerifiable() {
        String password="Strong-Demo-Pass-319!";
        String hashed=AccessService.hashPassword(password);
        assertNotEquals(hashed,AccessService.hashPassword(password));
        assertTrue(AccessService.verifyPassword(password,hashed));
        assertFalse(AccessService.verifyPassword("bad-password",hashed));
        assertThrows(Exception.class,()->AccessService.hashPassword("short"));
    }
}
