import { Component, signal, computed, inject, ChangeDetectionStrategy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { ReactiveFormsModule, FormBuilder, Validators, FormGroup } from '@angular/forms';
import { Router } from '@angular/router';
import { AuthService } from '../../../core/auth/auth.service';

@Component({
  selector: 'app-login',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule],
  templateUrl: './login.component.html',
  styleUrls: ['./login.component.scss'],
  changeDetection: ChangeDetectionStrategy.OnPush
})
export class LoginComponent {
  private readonly fb = inject(FormBuilder);
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  readonly isLoading = signal(false);
  readonly errorMessage = signal<string | null>(null);

  readonly loginForm: FormGroup = this.fb.group({
    email: ['', [Validators.required, Validators.email]],
    password: ['', [Validators.required, Validators.minLength(8)]],
    tenantCode: ['']
  });

  readonly emailInvalid = computed(() => {
    const ctrl = this.loginForm.get('email');
    return ctrl ? ctrl.invalid && ctrl.touched : false;
  });

  readonly passwordInvalid = computed(() => {
    const ctrl = this.loginForm.get('password');
    return ctrl ? ctrl.invalid && ctrl.touched : false;
  });

  onSubmit(): void {
    if (this.loginForm.invalid) {
      this.loginForm.markAllAsTouched();
      const firstInvalid = document.querySelector('[aria-invalid="true"]') as HTMLElement;
      firstInvalid?.focus();
      return;
    }

    this.isLoading.set(true);
    this.errorMessage.set(null);

    const { email, password, tenantCode } = this.loginForm.value;

    this.auth.login({
      email,
      password,
      tenantCode: tenantCode?.trim() || null
    }).subscribe({
      next: (res) => {
        this.isLoading.set(false);
        this.router.navigate([res.user.redirectUrl || '/']);
      },
      error: (err) => {
        this.isLoading.set(false);
        const msg = err?.error?.error || err?.error?.message || 'Identifiants incorrects';
        this.errorMessage.set(msg);
      }
    });
  }
}
