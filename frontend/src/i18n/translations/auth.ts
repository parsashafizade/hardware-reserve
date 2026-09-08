export const authFa = {
  auth: {
    common: {
      accessBadge: "HardwareReserve",
      connectedWorkspace: "رزروها و سرویس‌های شما، یک‌جا",
      workflowPoints: {
        conflictAware: "رزرو بدون تداخل زمانی",
        transparent: "قیمت و زمان آزاد پیش از تأیید",
        linkedAccess: "جزئیات سرویس در حساب شما",
      },
      workflowTitle: "از انتخاب تا دسترسی",
      workflowDescription: "سرور را انتخاب کنید، زمان را رزرو کنید و سرویس را تحویل بگیرید",
      visualAlt: "راهروی یک مرکز داده مدرن با ردیف‌های رک سرور",
      mobileCaption: "رزرو سرور، ساده و قابل پیگیری.",
      securityNote:
        "ورود امن از رزروها و اطلاعات سرویس شما محافظت می‌کند.",
      showPassword: "نمایش گذرواژه",
      hidePassword: "پنهان کردن گذرواژه",
      passwordHint: "گذرواژه باید بین ۸ تا ۱۲۸ نویسه باشد.",
      otp: {
        digitLabel: "رقم {{position}} از {{total}}",
        verified: "کد تأیید شد",
      },
      resend: {
        action: "ارسال دوباره کد",
        sending: "در حال ارسال...",
        availableIn: "ارسال دوباره تا {{seconds}} ثانیه دیگر",
      },
      passwordStrength: {
        label: "قدرت گذرواژه",
        weak: "ضعیف",
        medium: "متوسط",
        strong: "قوی",
        lengthRequirement: "بین ۸ تا ۱۲۸ نویسه",
      },
      emailLabel: "ایمیل",
      emailPlaceholder: "you@example.com",
      backToSignIn: "بازگشت به ورود",

      captcha: {
        label: "بررسی امنیتی",
        refresh: "تازه‌سازی",
        answer: "پاسخ",
        loading: "در حال دریافت بررسی امنیتی...",
        unavailable:
          "بررسی امنیتی در دسترس نیست. برای تلاش دوباره «تازه‌سازی» را بزنید.",
        hint: "پاسخ این سؤال ساده را وارد کنید.",
      },
    },

    login: {
      eyebrow: "ورود",
      title: "دوباره خوش آمدید.",
      description:
        "برای مشاهده رزروها، سرویس‌های فعال و اطلاعات حساب وارد شوید.",
      visualTitle: "رزروها و سرویس‌ها، یک‌جا.",
      visualCopy:
        "وضعیت رزرو، پرداخت و اطلاعات سرویس را از حساب خود ببینید.",
      identifierLabel: "ایمیل",
      identifierPlaceholder: "ایمیل خود را وارد کنید",
      passwordLabel: "گذرواژه",
      passwordPlaceholder: "گذرواژه خود را وارد کنید",
      forgotPassword: "گذرواژه را فراموش کرده‌اید؟",
      submit: "ورود",
      submitting: "در حال ورود...",
      newUser: "هنوز حساب ندارید؟",
      createAccount: "ساخت حساب",
      captchaLoadError: "بررسی امنیتی دریافت نشد.",
      captchaRequired: "ابتدا بررسی امنیتی را تکمیل کنید.",
      failed: "ورود انجام نشد. اطلاعات واردشده را بررسی کنید.",
    },

    register: {
      eyebrow: "ساخت حساب",
      title: "حساب کاربری بسازید.",
      description:
        "برای رزرو سرور و پیگیری سرویس‌ها، حساب بسازید.",
      visualTitle: "از انتخاب سرور تا تحویل سرویس.",
      visualCopy:
        "سرور را انتخاب کنید، زمان مناسب را رزرو کنید و ادامه کار را از حسابتان ببینید.",
      fullName: "نام و نام خانوادگی",
      fullNamePlaceholder: "نام کامل خود را وارد کنید",
      password: "گذرواژه",
      passwordPlaceholder: "یک گذرواژه انتخاب کنید",
      submit: "ساخت حساب",
      submitting: "در حال ساخت حساب...",
      existingUser: "از قبل حساب دارید؟",
      signIn: "وارد شوید",
      captchaRequired: "ابتدا بررسی امنیتی را تکمیل کنید.",
      failed: "ساخت حساب انجام نشد. لطفاً اطلاعات واردشده را بررسی کنید.",
    },

    verify: {
      eyebrow: "تأیید ایمیل",
      title: "ایمیلتان را تأیید کنید.",
      description:
        "کد ۶ رقمی ارسال‌شده را وارد کنید تا حسابتان فعال شود.",
      visualTitle: "یک قدم تا فعال شدن حساب.",
      visualCopy:
        "پس از تأیید ایمیل، حساب شما آماده استفاده است.",
      sentTo: "کد تأیید به این ایمیل ارسال شد:",
      codeLabel: "کد تأیید",
      codePlaceholder: "123456",
      submit: "تأیید و ادامه",
      submitting: "در حال تأیید...",
      resend: "ارسال دوباره کد",
      resending: "در حال ارسال...",
      resendCountdown: "ارسال دوباره تا {{seconds}} ثانیه دیگر",
      resendSuccess: "کد جدید ارسال شد.",
      resendFailed: "ارسال دوباره کد انجام نشد. لطفاً دوباره تلاش کنید.",
      failed: "کد تأیید نشد.",
      missingEmail:
        "ایمیل حساب مشخص نیست. دوباره از صفحه ورود یا ثبت‌نام ادامه دهید.",
      backToLogin: "بازگشت به ورود",
    },

    forgot: {
      eyebrow: "بازیابی گذرواژه",
      title: "گذرواژه را فراموش کرده‌اید؟",
      description:
        "ایمیل حسابتان را وارد کنید. اگر حسابی با این ایمیل باشد، کد بازیابی را برایتان می‌فرستیم.",
      visualTitle: "دسترسی به حسابتان را برگردانید.",
      visualCopy:
        "کد بازیابی فقط برای مدت کوتاهی معتبر است.",
      submit: "ارسال کد بازیابی",
      submitting: "در حال ارسال...",
      success:
        "اگر این ایمیل به حسابی متصل باشد، کد بازیابی برای آن ارسال شده است.",
    },

    reset: {
      eyebrow: "بازیابی گذرواژه",
      title: "گذرواژه جدید بسازید.",
      description:
        "ابتدا کد ارسال‌شده به ایمیل خود را تأیید کنید و سپس یک گذرواژه جدید انتخاب کنید.",
      visualTitle: "چند قدم کوتاه تا ورود دوباره.",
      visualCopy:
        "کد را تأیید کنید و یک گذرواژه جدید بسازید.",
      progressLabel: "مراحل بازیابی گذرواژه",
      steps: {
        email: "ایمیل",
        code: "کد تأیید",
        password: "گذرواژه جدید",
      },

      codeTitle: "کد بازیابی را وارد کنید.",
      codeDescription:
        "کد شش‌رقمی ارسال‌شده به {{email}} را وارد کنید.",
      codeLabel: "کد بازیابی",
      verifyCode: "تأیید کد",
      verifyingCode: "در حال بررسی...",
      invalidCode:
        "این کد معتبر نیست یا زمان استفاده از آن به پایان رسیده است.",
      resendSuccess: "کد بازیابی جدید ارسال شد.",
      resendFailed: "ارسال دوباره کد انجام نشد. کمی بعد دوباره تلاش کنید.",
      codeVerified:
        "کد تأیید شد. حالا گذرواژه جدید را وارد کنید.",

      passwordTitle: "گذرواژه جدید را وارد کنید.",
      passwordDescription:
        "گذرواژه جدید را یک بار دیگر تکرار کنید.",
      newPassword: "گذرواژه جدید",
      newPasswordPlaceholder: "گذرواژه جدید را وارد کنید",
      confirmPassword: "تکرار گذرواژه جدید",
      confirmPasswordPlaceholder: "گذرواژه جدید را دوباره وارد کنید",
      mismatch: "گذرواژه‌ها با هم مطابقت ندارند.",
      passwordsMatch: "گذرواژه‌ها یکسان‌اند.",

      submit: "تغییر گذرواژه",
      submitting: "در حال تغییر گذرواژه...",
      success: "گذرواژه تغییر کرد.",

      missingEmail:
        "برای ادامه، ابتدا ایمیل حساب خود را در صفحه بازیابی گذرواژه وارد کنید.",
      backToForgot: "بازگشت به بازیابی گذرواژه",
    },
  },
} as const;

export const authEn = {
  auth: {
    common: {
      accessBadge: "HardwareReserve",
      connectedWorkspace: "Your reservations and services, in one place",
      workflowPoints: {
        conflictAware: "Conflict-free reservation windows",
        transparent: "Pricing and available times before you confirm",
        linkedAccess: "Service details in your account",
      },
      workflowTitle: "From selection to access",
      workflowDescription: "Choose a server, reserve your time, and access your service",
      visualAlt: "A modern data center corridor lined with server racks",
      mobileCaption: "Server reservations, simple and easy to track.",
      securityNote:
        "Secure sign-in protects your reservations and service details.",
      showPassword: "Show password",
      hidePassword: "Hide password",
      passwordHint: "Password must be between 8 and 128 characters.",
      otp: {
        digitLabel: "Digit {{position}} of {{total}}",
        verified: "Code verified",
      },
      resend: {
        action: "Resend code",
        sending: "Sending...",
        availableIn: "Resend available in {{seconds}} seconds",
      },
      passwordStrength: {
        label: "Password strength",
        weak: "Weak",
        medium: "Medium",
        strong: "Strong",
        lengthRequirement: "Between 8 and 128 characters",
      },
      emailLabel: "Email",
      emailPlaceholder: "you@example.com",
      backToSignIn: "Back to sign in",

      captcha: {
        label: "Security check",
        refresh: "Refresh",
        answer: "Answer",
        loading: "Loading security check...",
        unavailable:
          "The security check is unavailable. Select Refresh to try again.",
        hint: "Answer this quick question to continue.",
      },
    },

    login: {
      eyebrow: "Sign in",
      title: "Welcome back.",
      description:
        "Sign in to view your reservations, active services, and account details.",
      visualTitle: "Reservations and services, in one place.",
      visualCopy:
        "Track reservations, payments, and service details from your account.",
      identifierLabel: "Email",
      identifierPlaceholder: "Enter your email",
      passwordLabel: "Password",
      passwordPlaceholder: "Enter your password",
      forgotPassword: "Forgot your password?",
      submit: "Sign in",
      submitting: "Signing in...",
      newUser: "Don't have an account yet?",
      createAccount: "Create account",
      captchaLoadError: "The security check could not be loaded.",
      captchaRequired: "Complete the security check before signing in.",
      failed: "We couldn't sign you in. Check your details and try again.",
    },

    register: {
      eyebrow: "Create account",
      title: "Create your account.",
      description:
        "Create an account to reserve servers and track your services.",
      visualTitle: "From server selection to service access.",
      visualCopy:
        "Choose a server, reserve your time, and track what happens next from your account.",
      fullName: "Full name",
      fullNamePlaceholder: "Enter your full name",
      password: "Password",
      passwordPlaceholder: "Choose a password",
      submit: "Create account",
      submitting: "Creating account...",
      existingUser: "Already have an account?",
      signIn: "Sign in",
      captchaRequired: "Complete the security check before creating your account.",
      failed: "We couldn't create your account. Check your details and try again.",
    },

    verify: {
      eyebrow: "Email verification",
      title: "Verify your email.",
      description:
        "Enter the six-digit code we sent to activate your account.",
      visualTitle: "One step until your account is ready.",
      visualCopy:
        "Once your email is verified, your account is ready to use.",
      sentTo: "Verification code sent to:",
      codeLabel: "Verification code",
      codePlaceholder: "123456",
      submit: "Verify and continue",
      submitting: "Verifying...",
      resend: "Resend code",
      resending: "Sending...",
      resendCountdown: "You can resend the code in {{seconds}} seconds",
      resendSuccess: "A new code has been sent.",
      resendFailed: "We couldn't resend the code. Please try again.",
      failed: "We couldn't verify that code.",
      missingEmail:
        "We don't have an email address to verify. Return to sign in or registration and try again.",
      backToLogin: "Back to sign in",
    },

    forgot: {
      eyebrow: "Password recovery",
      title: "Forgot your password?",
      description:
        "Enter your account email. If it matches an account, we'll send a recovery code.",
      visualTitle: "Get back into your account.",
      visualCopy:
        "Your recovery code is valid for a limited time.",
      submit: "Send recovery code",
      submitting: "Sending...",
      success:
        "If an account matches this email, a recovery code has been sent.",
    },

    reset: {
      eyebrow: "Password recovery",
      title: "Create a new password.",
      description:
        "Verify the code sent to your email, then choose a new password.",
      visualTitle: "A few short steps to sign back in.",
      visualCopy:
        "Verify the code, then set a new password.",
      progressLabel: "Password recovery progress",
      steps: {
        email: "Email",
        code: "Verification",
        password: "New password",
      },

      codeTitle: "Enter your recovery code.",
      codeDescription:
        "Enter the six-digit code sent to {{email}}.",
      codeLabel: "Recovery code",
      verifyCode: "Verify code",
      verifyingCode: "Verifying...",
      invalidCode:
        "This code is invalid or has expired.",
      resendSuccess: "A new recovery code has been sent.",
      resendFailed: "We couldn't resend the code. Please try again shortly.",
      codeVerified:
        "Code verified. You can now enter a new password.",

      passwordTitle: "Enter a new password.",
      passwordDescription:
        "Enter the new password again to confirm it.",
      newPassword: "New password",
      newPasswordPlaceholder: "Enter your new password",
      confirmPassword: "Confirm new password",
      confirmPasswordPlaceholder: "Enter your new password again",
      mismatch: "The passwords don't match.",
      passwordsMatch: "Passwords match.",

      submit: "Reset password",
      submitting: "Resetting password...",
      success: "Your password has been changed.",

      missingEmail:
        "To continue, enter your account email from the password recovery page first.",
      backToForgot: "Back to password recovery",
    },
  },
} as const;
