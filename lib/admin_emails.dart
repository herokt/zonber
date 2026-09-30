// 관리자 이메일 — 백오피스 로그인(backoffice/admin_gate.dart) · 푸시 시험 기기(services/push_service.dart 의 tester 토픽)가 같이 쓴다.
// firestore.rules 의 isAdmin() 과 functions/index.js 의 ADMIN_EMAILS 도 같은 목록이다(바꾸면 넷 다 고칠 것).
const Set<String> kAdminEmails = {'herokt851103@gmail.com'};
