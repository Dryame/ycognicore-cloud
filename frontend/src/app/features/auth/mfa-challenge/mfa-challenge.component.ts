import { Component, ChangeDetectionStrategy, inject, signal, computed } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { HttpClient } from '@angular/common/http';
import { AuthService } from '../../../core/auth/auth.service';
import { environment } from '../../../../environments/environment';
import { LoginResponse } from '../../../core/models/login.model';

@Component({
  selector: 'app-mfa-challenge',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './mfa-challenge.component.html',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class MfaChallengeComponent {
  private readonly fb = inject(FormBuilder);
  private readonly http = inject(HttpClient);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  readonly isLoading = signal(false);
  readonly errorMessage = signal<string | null>(null);

  private readonly challengeToken: string =
    (history.state?.challengeToken as string | undefined) ?? '';

  readonly form = this.fb.group({
    code: ['', [Validators.required, Validators.pattern(/^\d{6}$/)]],
  });

  readonly codeInvalid = computed(() => {
    const c = this.form.get('code');
    return c ? c.invalid && c.touched : false;
  });

  constructor() {
    if (!this.challengeToken) {
      this.router.navigate(['/login']);
    }
  }

  onSubmit(): void {
    if (this.form.invalid) {
      this.form.markAllAsTouched();
      return;
    }
    this.isLoading.set(true);
    this.errorMessage.set(null);

    this.http.post<LoginResponse>(
      `${environment.apiUrl}/api/mfa/challenge-verify`,
      {
        challengeToken: this.challengeToken,
        code: this.form.value.code,
      },
      { withCredentials: true }
    ).subscribe({
      next: (res) => {
        this.isLoading.set(false);
        if (res.mfaRequired) {
          this.errorMessage.set('Code MFA invalide');
          return;
        }
        this.auth.completeLogin(res);
        this.router.navigate([res.user.redirectUrl || '/']);
      },
      error: (err) => {
        this.isLoading.set(false);
        this.errorMessage.set(
          err?.error?.error || err?.error?.message || 'Code MFA invalide'
        );
      },
    });
  }

  cancel(): void {
    this.router.navigate(['/login']);
  }
}
