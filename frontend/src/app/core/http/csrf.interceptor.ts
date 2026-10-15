import { HttpInterceptorFn } from '@angular/common/http';

/**
 * Double-submit CSRF (D-13) : cookie XSRF-TOKEN -> header X-XSRF-TOKEN.
 */
export const csrfInterceptor: HttpInterceptorFn = (req, next) => {
  const mutating = ['POST', 'PUT', 'PATCH', 'DELETE'].includes(req.method);
  if (!mutating) {
    return next(req);
  }

  const token = readCookie('XSRF-TOKEN');
  if (!token) {
    return next(req);
  }

  const cloned = req.clone({
    setHeaders: { 'X-XSRF-TOKEN': token },
    withCredentials: true,
  });
  return next(cloned);
};

function readCookie(name: string): string | null {
  const match = document.cookie.match(
    new RegExp('(^|;\\s*)' + name + '=([^;]*)')
  );
  return match ? decodeURIComponent(match[2]) : null;
}
