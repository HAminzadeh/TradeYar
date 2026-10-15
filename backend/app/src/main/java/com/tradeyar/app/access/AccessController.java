package com.tradeyar.app.access;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;
import java.util.Map;
import java.util.UUID;

/** SakhtYar-inspired API contract with TradeYar-specific research permissions. */
@RestController
@RequestMapping("/api/v1")
public final class AccessController {
    private final AccessService access;
    public AccessController(AccessService access) {this.access=access;}
    private static void require(boolean valid){if(!valid)throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,"مدیریت کاربران هنوز فعال نیست.");}
    private void ready(){require(access.enabled()&&access.configured());}
    public record LoginRequest(String username,String password) {}
    public record RegisterRequest(String username,String displayName,String email,String password) {}
    public record CreateRequest(String username,String displayName,String email,String password,String role,String status) {}
    public record UpdateRequest(String displayName,String email,String role,String status) {}
    public record ResetRequest(String newPassword) {}
    public record Registration(String message,String status) {}
    private static AccessService.Verified identity(HttpServletRequest request){
        Object value=request.getAttribute(AccessFilter.IDENTITY);
        if(value instanceof AccessService.Verified verified)return verified;
        throw new ResponseStatusException(HttpStatus.UNAUTHORIZED,"نشست معتبر نیست.");
    }
    private static UUID actor(HttpServletRequest req) {return UUID.fromString(identity(req).user().id());}
    private static void requireAdmin(HttpServletRequest req) {
        if(!identity(req).user().permissions().contains("USER_MANAGE"))
            throw new ResponseStatusException(HttpStatus.FORBIDDEN,"مجوز مدیریت کاربران ندارید.");
    }
    private static void cookie(HttpServletRequest req,HttpServletResponse res,String name,String value,int maxAge,boolean httpOnly){
        String header=name+"="+value+"; Path=/; SameSite=Strict; Max-Age="+maxAge+(httpOnly?"; HttpOnly":"")+(req.isSecure()?"; Secure":"");
        res.addHeader("Set-Cookie",header);
    }
    @GetMapping("/auth/status")
    public Map<String,Boolean> status(){return Map.of("enabled",access.enabled(),"configured",access.configured());}
    @PostMapping("/auth/register")
    public Registration register(@RequestBody RegisterRequest input){ready();access.register(input.username(),input.displayName(),input.email(),input.password());return new Registration("درخواست ثبت شد؛ پس از تأیید مدیر می‌توانید وارد شوید.","PENDING");}
    @PostMapping("/auth/login")
    public Map<String,AccessService.UserView> login(@RequestBody LoginRequest input,HttpServletRequest req,HttpServletResponse res){
        ready();AccessService.Session session=access.login(input.username(),input.password());
        cookie(req,res,"tradeyar_session",session.token(),43200,true);
        cookie(req,res,"tradeyar_csrf",session.csrf(),43200,false);
        res.setHeader("Cache-Control","no-store");
        return Map.of("user",session.user());
    }
    @GetMapping("/auth/me")
    public AccessService.UserView me(HttpServletRequest req){ready();return identity(req).user();}
    @PostMapping("/auth/logout")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(HttpServletRequest req,HttpServletResponse res){ready();access.logout(AccessFilter.cookie(req,"tradeyar_session"));
        cookie(req,res,"tradeyar_session","",0,true);cookie(req,res,"tradeyar_csrf","",0,false);
    }
    @GetMapping("/admin/users")
    public List<AccessService.UserView> users(HttpServletRequest req){ready();requireAdmin(req);return access.list();}
    @PostMapping("/admin/users")
    public AccessService.UserView create(@RequestBody CreateRequest body,HttpServletRequest req){
        ready();requireAdmin(req);return access.create(body.username(),body.displayName(),body.email(),body.password(),body.role(),body.status(),actor(req));
    }
    @PutMapping("/admin/users/{id}")
    public AccessService.UserView update(@PathVariable UUID id,@RequestBody UpdateRequest body,HttpServletRequest req){
        ready();requireAdmin(req);return access.update(id,body.displayName(),body.email(),body.role(),body.status(),actor(req));
    }
    @PostMapping("/admin/users/{id}/reset-password")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void reset(@PathVariable UUID id,@RequestBody ResetRequest body,HttpServletRequest req){ready();requireAdmin(req);access.reset(id,body.newPassword(),actor(req));}
    @PostMapping("/admin/users/{id}/unlock")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void unlock(@PathVariable UUID id,HttpServletRequest req){ready();requireAdmin(req);access.unlock(id,actor(req));}
}
