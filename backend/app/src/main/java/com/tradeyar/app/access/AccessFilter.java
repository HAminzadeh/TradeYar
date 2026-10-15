package com.tradeyar.app.access;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.core.Ordered;
import org.springframework.core.annotation.Order;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import org.springframework.web.server.ResponseStatusException;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Arrays;
import java.util.Set;

/** Enforces server-side RBAC and CSRF for all TradeYar /api routes when enabled. */
@Component
@Order(Ordered.HIGHEST_PRECEDENCE + 10)
public final class AccessFilter extends OncePerRequestFilter {
    public static final String IDENTITY = "tradeyar.verified";
    private final AccessService access;
    public AccessFilter(AccessService access) {this.access=access;}
    public static String cookie(HttpServletRequest r,String name) {
        if(r.getCookies()==null)return null;
        for(Cookie c:r.getCookies())if(name.equals(c.getName()))return c.getValue();
        return null;
    }
    private static void deny(HttpServletResponse response,int status,String message)throws IOException {
        response.setStatus(status);response.setContentType("application/json;charset=UTF-8");
        response.setHeader("Cache-Control","no-store");
        response.getWriter().write("{\"message\":\""+message+"\"}");
    }
    @Override
    protected void doFilterInternal(HttpServletRequest request,HttpServletResponse response,FilterChain chain) throws ServletException,IOException {
        if(!access.enabled()||!request.getRequestURI().startsWith("/api/")) {chain.doFilter(request,response);return;}
        String path=request.getRequestURI();String method=request.getMethod().toUpperCase();
        if("OPTIONS".equals(method)) {chain.doFilter(request,response);return;}
        boolean unsafe=!Set.of("GET","HEAD","OPTIONS").contains(method);
        if(unsafe) {
            String fetchSite=request.getHeader("Sec-Fetch-Site");
            if("cross-site".equalsIgnoreCase(fetchSite)) {deny(response,403,"درخواست نامعتبر است.");return;}
            String origin=request.getHeader("Origin");
            if(origin!=null&&!allowedOrigin(origin)) {deny(response,403,"مبدأ درخواست مجاز نیست.");return;}
        }
        if (("GET".equals(method) && (path.equals("/api/health")||path.equals("/api/v1/auth/status")))
           || ("POST".equals(method)&&(path.equals("/api/v1/auth/login")||path.equals("/api/v1/auth/register")))){
            chain.doFilter(request,response);return;
        }
        if(!access.configured()){deny(response,503,"مدیریت کاربران پیکربندی نشده است.");return;}
        AccessService.Verified session;
        try {session=access.verifySession(cookie(request,"tradeyar_session"));}
        catch(ResponseStatusException ex) {deny(response,503,"ارتباط با سرویس دسترسی ناموفق بود.");return;}
        if(session==null){deny(response,401,"برای استفاده از سامانه باید وارد شوید.");return;}
        request.setAttribute(IDENTITY,session);
        if(unsafe) {
            String csrf=request.getHeader("X-TradeYar-CSRF");
            if(csrf==null || !MessageDigest.isEqual(csrf.getBytes(StandardCharsets.UTF_8),session.csrf().getBytes(StandardCharsets.UTF_8))) {
                deny(response,403,"توکن امنیتی درخواست معتبر نیست.");return;
            }
        }
        Set<String> perms=session.user().permissions();
        if(path.startsWith("/api/v1/admin/users") && !perms.contains("USER_MANAGE")){
            deny(response,403,"مجوز مدیریت کاربران ندارید.");return;
        }
        if(!perms.contains("RESEARCH_READ")) {deny(response,403,"مجوز دسترسی ندارید.");return;}
        if(unsafe && !path.equals("/api/v1/auth/logout") && !path.startsWith("/api/v1/admin/users")){
            boolean paper=path.startsWith("/api/paper") || path.startsWith("/api/v05/paper") || path.startsWith("/api/v06/paper");
            if(!perms.contains(paper?"PAPER_TRADE":"RESEARCH_RUN")) {
                deny(response,403,"مجوز اجرای این عملیات ندارید.");return;
            }
        }
        // This filter does not unlock or alter the independent live-order HTTP 423 gate.
        chain.doFilter(request,response);
    }
    private static boolean allowedOrigin(String origin){
        String list=System.getenv().getOrDefault("TRADEYAR_AUTH_ALLOWED_ORIGINS",
            "http://127.0.0.1:5173,http://localhost:5173,http://127.0.0.1:8080,http://localhost:8080");
        return Arrays.stream(list.split(",")).map(String::trim).anyMatch(origin::equals);
    }
}
