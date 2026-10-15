package com.tradeyar.app.access;

import jakarta.annotation.PostConstruct;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.web.server.ResponseStatusException;

import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.PBEKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.sql.*;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.regex.Pattern;

/** PostgreSQL-backed local research users. No credentials, session tokens or hashes are logged. */
@Service
public final class AccessService {
    private static final SecureRandom RNG = new SecureRandom();
    private static final Pattern USERNAME = Pattern.compile("[A-Za-z0-9_.-]{3,60}");
    private static final int PBKDF2_ROUNDS = 310_000;
    private static final long SESSION_HOURS = 12;
    private final String url = System.getenv("TRADEYAR_AUTH_DB_URL");
    private final String dbUser = System.getenv("TRADEYAR_AUTH_DB_USER");
    private final String dbPassword = System.getenv("TRADEYAR_AUTH_DB_PASSWORD");
    private final boolean enabled = Boolean.parseBoolean(System.getenv().getOrDefault("TRADEYAR_AUTH_ENABLED", "false"));

    public boolean enabled() { return enabled; }
    public boolean configured() {return url != null && url.startsWith("jdbc:postgresql:") && notEmpty(dbUser) && notEmpty(dbPassword);}
    private static boolean notEmpty(String s) {return s != null && !s.isBlank();}
    private Connection connection() throws SQLException {
        if (!enabled || !configured()) throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE, "مدیریت کاربران پیکربندی نشده است.");
        return DriverManager.getConnection(url, dbUser, dbPassword);
    }
    private static ResponseStatusException error(HttpStatus code, String message) {return new ResponseStatusException(code,message);}
    private static void audit(Connection conn, UUID user, String event, String detail) throws SQLException {
        try (PreparedStatement p=conn.prepareStatement("INSERT INTO tradeyar_auth.audit(user_id,action,description) VALUES (?,?,?)")) {
            if(user==null)p.setNull(1,Types.OTHER);else p.setObject(1,user);
            p.setString(2,event);p.setString(3,detail);p.executeUpdate();
        }
    }
    private static void validatePassword(String password) {
        if(password==null || password.length()<12 || password.length()>128 || !password.matches("(?s).*[A-Za-z].*") || !password.matches("(?s).*\\d.*") || !password.matches("(?s).*[!@#$%^&*()_+\\-=\\[\\]{}:;,.?/].*"))
            throw error(HttpStatus.BAD_REQUEST,"رمز باید بین ۱۲ تا ۱۲۸ کاراکتر و شامل حرف لاتین، عدد و نماد باشد.");
    }
    private static String normalizeUsername(String value) {
        String v=value==null?"":value.trim();
        if(!USERNAME.matcher(v).matches()) throw error(HttpStatus.BAD_REQUEST,"نام کاربری باید ۳ تا ۶۰ نویسه لاتین/عدد/._- باشد.");
        return v;
    }
    private static String validateName(String value) {
        String v=value==null?"":value.trim();
        if(v.length()<2||v.length()>120)throw error(HttpStatus.BAD_REQUEST,"نام نمایشی باید بین ۲ تا ۱۲۰ کاراکتر باشد.");
        return v;
    }
    private static String normalizeEmail(String value) {
        if(value==null||value.isBlank())return null;
        String e=value.trim().toLowerCase(Locale.ROOT);
        if(e.length()>255||!e.matches("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"))throw error(HttpStatus.BAD_REQUEST,"ایمیل معتبر نیست.");
        return e;
    }
    private static String token() {byte[] b=new byte[32];RNG.nextBytes(b);return Base64.getUrlEncoder().withoutPadding().encodeToString(b);}
    private static String hex(byte[] b) {return HexFormat.of().formatHex(b);}
    static String digest(String s) {
        try {return hex(MessageDigest.getInstance("SHA-256").digest(s.getBytes(StandardCharsets.UTF_8)));}
        catch(Exception e){throw new IllegalStateException("SHA-256 not available",e);}
    }
    static String hashPassword(String value) {
        validatePassword(value);byte[] salt=new byte[16];RNG.nextBytes(salt);
        return "pbkdf2-sha256$"+PBKDF2_ROUNDS+"$"+Base64.getEncoder().encodeToString(salt)+"$"+Base64.getEncoder().encodeToString(pbkdf(value,salt,PBKDF2_ROUNDS));
    }
    private static byte[] pbkdf(String pass,byte[] salt,int rounds) {
        PBEKeySpec spec=new PBEKeySpec(pass.toCharArray(),salt,rounds,256);
        try{return SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).getEncoded();}
        catch(Exception e){throw new IllegalStateException("Unable to hash password",e);}finally{spec.clearPassword();}
    }
    static boolean verifyPassword(String input,String encoded) {
        try {
            String[] pieces=encoded.split("\\$");
            if(pieces.length!=4||!pieces[0].equals("pbkdf2-sha256"))return false;
            int rounds=Integer.parseInt(pieces[1]);if(rounds<100_000 || rounds>500_000)return false;
            return MessageDigest.isEqual(Base64.getDecoder().decode(pieces[3]),pbkdf(input==null?"":input,Base64.getDecoder().decode(pieces[2]),rounds));
        }catch(RuntimeException e){return false;}
    }
    public static Set<String> permissions(String role) {
        return switch(role) {
            case "ADMIN" -> Set.of("USER_MANAGE","RESEARCH_READ","RESEARCH_RUN","PAPER_TRADE","AUDIT_READ");
            case "RESEARCH_MANAGER" -> Set.of("RESEARCH_READ","RESEARCH_RUN","PAPER_TRADE","AUDIT_READ");
            case "ANALYST" -> Set.of("RESEARCH_READ","RESEARCH_RUN");
            default -> Set.of("RESEARCH_READ");
        };
    }
    public record UserView(String id,String username,String displayName,String email,String role,String status,Set<String> permissions,String lastLoginAt,String lockedUntil) {}
    public record Session(String token,String csrf,UserView user) {}
    public record Verified(UserView user,String csrf) {}
    private static String date(Timestamp t) {return t==null?null:t.toInstant().toString();}
    private static UserView user(ResultSet rs)throws SQLException {
        String role=rs.getString("role");
        return new UserView(rs.getObject("id").toString(),rs.getString("username"),rs.getString("display_name"),rs.getString("email"),role,rs.getString("status"),permissions(role),date(rs.getTimestamp("last_login_at")),date(rs.getTimestamp("locked_until")));
    }
    private static UserView byId(Connection c,UUID id)throws SQLException {
        try(PreparedStatement p=c.prepareStatement("SELECT * FROM tradeyar_auth.users WHERE id=?")){
            p.setObject(1,id);try(ResultSet rs=p.executeQuery()){if(rs.next())return user(rs);}
        }
        throw error(HttpStatus.NOT_FOUND,"کاربر پیدا نشد.");
    }
    @PostConstruct
    public void bootstrap() {
        if(!enabled || !configured())return;
        String admin=System.getenv("TRADEYAR_AUTH_BOOTSTRAP_USERNAME");
        String secret=System.getenv("TRADEYAR_AUTH_BOOTSTRAP_PASSWORD");
        if(!notEmpty(admin)||!notEmpty(secret))return;
        try(Connection c=connection()){
            c.setAutoCommit(false);
            // DB-level advisory lock prevents competing first-run bootstrap attempts.
            try(Statement lock=c.createStatement()){lock.execute("SELECT pg_advisory_xact_lock(62015043)");}
            int count;
            try(Statement st=c.createStatement();ResultSet r=st.executeQuery("SELECT COUNT(*) FROM tradeyar_auth.users WHERE role='ADMIN'")){r.next();count=r.getInt(1);}
            if(count==0){createTx(c,admin,"مدیر تریدیار",null,secret,"ADMIN","ACTIVE");audit(c,null,"ADMIN_BOOTSTRAPPED","initial admin account created");}
            c.commit();
        }catch(SQLException e){throw new IllegalStateException("TradeYar auth bootstrap requires the explicitly applied database migration",e);}
    }
    private static UserView createTx(Connection c,String username,String name,String email,String password,String role,String status) throws SQLException {
        UUID id=UUID.randomUUID();String normalized=normalizeUsername(username);
        try(PreparedStatement p=c.prepareStatement("INSERT INTO tradeyar_auth.users(id,username,display_name,email,password_hash,role,status) VALUES(?,?,?,?,?,?,?)")){
            p.setObject(1,id);p.setString(2,normalized);p.setString(3,validateName(name));p.setString(4,normalizeEmail(email));p.setString(5,hashPassword(password));p.setString(6,role);p.setString(7,status);p.executeUpdate();
        }
        return byId(c,id);
    }
    private static void validateRole(String role) {if(role==null||!Set.of("ADMIN","RESEARCH_MANAGER","ANALYST","VIEWER").contains(role))throw error(HttpStatus.BAD_REQUEST,"نقش نامعتبر است.");}
    private static void validateStatus(String status) {if(status==null||!Set.of("PENDING","ACTIVE","SUSPENDED").contains(status))throw error(HttpStatus.BAD_REQUEST,"وضعیت نامعتبر است.");}
    private static ResponseStatusException sqlError(SQLException e) {
        return error("23505".equals(e.getSQLState())?HttpStatus.CONFLICT:HttpStatus.SERVICE_UNAVAILABLE,
            "23505".equals(e.getSQLState())?"نام کاربری یا ایمیل تکراری است.":"ارتباط با پایگاه داده مدیریت کاربران ناموفق بود.");
    }
    public UserView register(String username,String name,String email,String password) {
        try(Connection c=connection()) {c.setAutoCommit(false);UserView v=createTx(c,username,name,email,password,"VIEWER","PENDING");audit(c,UUID.fromString(v.id()),"REGISTERED","pending account");c.commit();return v;}
        catch(SQLException e){throw sqlError(e);}
    }
    public UserView create(String username,String name,String email,String password,String role,String status,UUID actor) {
        validateRole(role);validateStatus(status);
        try(Connection c=connection()){c.setAutoCommit(false);UserView v=createTx(c,username,name,email,password,role,status);audit(c,actor,"USER_CREATED",v.id());c.commit();return v;}
        catch(SQLException e){throw sqlError(e);}
    }
    public Session login(String username,String password) {
        String name=username==null?"":username.trim();
        // Avoid connection state leaking across exception paths; commit failed-login counters.
        try(Connection c=connection()){
            c.setAutoCommit(false);UUID id=null;String hash=null;String status=null;Timestamp lock=null;int failed=0;
            try(PreparedStatement p=c.prepareStatement("SELECT * FROM tradeyar_auth.users WHERE lower(username)=lower(?) FOR UPDATE")){
                p.setString(1,name);
                try(ResultSet r=p.executeQuery()){if(r.next()){id=(UUID)r.getObject("id");hash=r.getString("password_hash");status=r.getString("status");lock=r.getTimestamp("locked_until");failed=r.getInt("failed_attempts");}}
            }
            // Compute an expensive dummy hash even when the username doesn't exist.
            if(id==null){pbkdf(password==null?"":password,new byte[16],PBKDF2_ROUNDS);throw error(HttpStatus.UNAUTHORIZED,"نام کاربری یا رمز عبور اشتباه است.");}
            if(!"ACTIVE".equals(status))throw error(HttpStatus.FORBIDDEN,"حساب فعال نیست یا هنوز تأیید نشده است.");
            if(lock!=null&&lock.toInstant().isAfter(Instant.now()))throw error(HttpStatus.LOCKED,"حساب موقتاً قفل شده است.");
            if(!verifyPassword(password,hash)){
                int attempts=failed+1;
                try(PreparedStatement p=c.prepareStatement("UPDATE tradeyar_auth.users SET failed_attempts=?,locked_until=?,updated_at=now() WHERE id=?")){
                    p.setInt(1,attempts);
                    if(attempts>=5)p.setTimestamp(2,Timestamp.from(Instant.now().plus(15,ChronoUnit.MINUTES)));else p.setNull(2,Types.TIMESTAMP_WITH_TIMEZONE);
                    p.setObject(3,id);p.executeUpdate();
                }
                audit(c,id,"LOGIN_FAILED","invalid password");c.commit();
                throw error(attempts>=5?HttpStatus.LOCKED:HttpStatus.UNAUTHORIZED,attempts>=5?"حساب به مدت ۱۵ دقیقه قفل شد.":"نام کاربری یا رمز عبور اشتباه است.");
            }
            try(PreparedStatement p=c.prepareStatement("UPDATE tradeyar_auth.users SET failed_attempts=0,locked_until=NULL,last_login_at=now(),updated_at=now() WHERE id=?")){
                p.setObject(1,id);p.executeUpdate();
            }
            String rawToken=token(),csrf=token();
            try(PreparedStatement p=c.prepareStatement("INSERT INTO tradeyar_auth.sessions(token_hash,user_id,csrf_token,expires_at) VALUES(?,?,?,?)")){
                p.setString(1,digest(rawToken));p.setObject(2,id);p.setString(3,csrf);p.setTimestamp(4,Timestamp.from(Instant.now().plus(SESSION_HOURS,ChronoUnit.HOURS)));p.executeUpdate();
            }
            audit(c,id,"LOGIN_SUCCEEDED","session issued");UserView view=byId(c,id);c.commit();return new Session(rawToken,csrf,view);
        }catch(SQLException e){throw sqlError(e);}
    }
    public Verified verifySession(String rawToken) {
        if(!notEmpty(rawToken))return null;
        try(Connection c=connection();PreparedStatement p=c.prepareStatement("SELECT u.*,s.csrf_token FROM tradeyar_auth.sessions s JOIN tradeyar_auth.users u ON u.id=s.user_id WHERE s.token_hash=? AND s.expires_at>now() AND u.status='ACTIVE'")){
            p.setString(1,digest(rawToken));try(ResultSet r=p.executeQuery()){return r.next()?new Verified(user(r),r.getString("csrf_token")):null;}
        }catch(SQLException e){throw sqlError(e);}
    }
    public void logout(String rawToken) {
        if(!notEmpty(rawToken))return;
        try(Connection c=connection();PreparedStatement p=c.prepareStatement("DELETE FROM tradeyar_auth.sessions WHERE token_hash=?")){
            p.setString(1,digest(rawToken));p.executeUpdate();
        }catch(SQLException e){throw sqlError(e);}
    }
    public List<UserView> list() {
        try(Connection c=connection();Statement p=c.createStatement();ResultSet r=p.executeQuery("SELECT * FROM tradeyar_auth.users ORDER BY created_at DESC LIMIT 1000")){
            List<UserView> result=new ArrayList<>();while(r.next())result.add(user(r));return result;
        }catch(SQLException e){throw sqlError(e);}
    }
    private static int activeAdminCount(Connection c)throws SQLException {
        try(Statement st=c.createStatement();ResultSet rs=st.executeQuery("SELECT COUNT(*) FROM tradeyar_auth.users WHERE role='ADMIN' AND status='ACTIVE'")){rs.next();return rs.getInt(1);}
    }
    public UserView update(UUID id,String name,String email,String role,String status,UUID actor) {
        validateRole(role);validateStatus(status);String cleaned=validateName(name);String mail=normalizeEmail(email);
        try(Connection c=connection()){
            c.setAutoCommit(false);UserView before;
            // Serialize all role/status modifications to preserve at least one active administrator.
            try(Statement guard=c.createStatement()){guard.execute("SELECT pg_advisory_xact_lock(62015044)");}
            try(PreparedStatement lock=c.prepareStatement("SELECT * FROM tradeyar_auth.users WHERE id=? FOR UPDATE")){
                lock.setObject(1,id);try(ResultSet rs=lock.executeQuery()){if(!rs.next())throw error(HttpStatus.NOT_FOUND,"کاربر پیدا نشد.");before=user(rs);}
            }
            if("ADMIN".equals(before.role())&&"ACTIVE".equals(before.status())&&(!"ADMIN".equals(role)||!"ACTIVE".equals(status))&&activeAdminCount(c)<=1)
                throw error(HttpStatus.CONFLICT,"آخرین مدیر فعال را نمی‌توان تعلیق یا حذف کرد.");
            try(PreparedStatement p=c.prepareStatement("UPDATE tradeyar_auth.users SET display_name=?,email=?,role=?,status=?,updated_at=now() WHERE id=?")){
                p.setString(1,cleaned);p.setString(2,mail);p.setString(3,role);p.setString(4,status);p.setObject(5,id);p.executeUpdate();
            }
            if(!"ACTIVE".equals(status) || !role.equals(before.role())){
                try(PreparedStatement p=c.prepareStatement("DELETE FROM tradeyar_auth.sessions WHERE user_id=?")){p.setObject(1,id);p.executeUpdate();}
            }
            audit(c,actor,"USER_UPDATED",id.toString());UserView after=byId(c,id);c.commit();return after;
        }catch(SQLException e){throw sqlError(e);}
    }
    public void reset(UUID id,String password,UUID actor) {
        String hash=hashPassword(password);
        try(Connection c=connection()){
            c.setAutoCommit(false);
            try(PreparedStatement p=c.prepareStatement("UPDATE tradeyar_auth.users SET password_hash=?,updated_at=now() WHERE id=?")){
                p.setString(1,hash);p.setObject(2,id);if(p.executeUpdate()==0)throw error(HttpStatus.NOT_FOUND,"کاربر پیدا نشد.");
            }
            try(PreparedStatement p=c.prepareStatement("DELETE FROM tradeyar_auth.sessions WHERE user_id=?")){p.setObject(1,id);p.executeUpdate();}
            audit(c,actor,"PASSWORD_RESET",id.toString());c.commit();
        }catch(SQLException e){throw sqlError(e);}
    }
    public void unlock(UUID id,UUID actor) {
        try(Connection c=connection()){
            c.setAutoCommit(false);
            try(PreparedStatement p=c.prepareStatement("UPDATE tradeyar_auth.users SET failed_attempts=0,locked_until=NULL,updated_at=now() WHERE id=?")){
                p.setObject(1,id);if(p.executeUpdate()==0)throw error(HttpStatus.NOT_FOUND,"کاربر پیدا نشد.");
            }
            audit(c,actor,"ACCOUNT_UNLOCKED",id.toString());c.commit();
        }catch(SQLException e){throw sqlError(e);}
    }
}
