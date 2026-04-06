<?php
// backend/api/mail_helper.php
// Shared PHPMailer helper (SMTP via env vars)

function require_composer_autoload_or_fail()
{
    $autoload = __DIR__ . '/vendor/autoload.php';
    if (!file_exists($autoload)) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'error' => 'Mailer dependency missing (vendor/autoload.php not found). Run composer install on the server.'
        ]);
        exit;
    }
    require_once $autoload;
}

function get_env_or_null($key)
{
    $val = getenv($key);
    if ($val === false) return null;
    $trimmed = trim((string)$val);
    return $trimmed === '' ? null : $trimmed;
}

function build_phpmailer_or_fail()
{
    $smtpHost = get_env_or_null('SMTP_HOST');
    $smtpUser = get_env_or_null('SMTP_USERNAME');
    $smtpPass = get_env_or_null('SMTP_PASSWORD');
    $smtpPort = get_env_or_null('SMTP_PORT');
    $smtpSecure = get_env_or_null('SMTP_SECURE'); // 'tls'|'ssl'|null
    $fromEmail = get_env_or_null('MAIL_FROM_EMAIL');
    $fromName = get_env_or_null('MAIL_FROM_NAME') ?? 'Pharmacy POS';

    if (!$smtpHost || !$smtpUser || !$smtpPass || !$smtpPort || !$fromEmail) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'error' => 'SMTP not configured. Please set SMTP_HOST, SMTP_USERNAME, SMTP_PASSWORD, SMTP_PORT, MAIL_FROM_EMAIL.'
        ]);
        exit;
    }

    require_composer_autoload_or_fail();

    $mail = new \PHPMailer\PHPMailer\PHPMailer(true);
    $mail->isSMTP();
    $mail->Host = $smtpHost;
    $mail->SMTPAuth = true;
    $mail->Username = $smtpUser;
    $mail->Password = $smtpPass;
    $mail->Port = (int)$smtpPort;

    if ($smtpSecure) {
        $mail->SMTPSecure = $smtpSecure;
    }

    $mail->setFrom($fromEmail, $fromName);
    $mail->isHTML(true);
    $mail->CharSet = 'UTF-8';

    return $mail;
}

function send_admin_pin_otp_email_or_fail($toEmail, $otp, $minutesValid)
{
    $mail = build_phpmailer_or_fail();

    $mail->addAddress($toEmail);
    $mail->Subject = 'Your Admin PIN Reset Code';

    $safeOtp = htmlspecialchars((string)$otp, ENT_QUOTES, 'UTF-8');
    $safeMinutes = (int)$minutesValid;

    $mail->Body = "
      <div style=\"font-family:Arial,sans-serif;line-height:1.6\">
        <h2 style=\"margin:0 0 12px 0\">Admin PIN Reset</h2>
        <p>Your OTP code is:</p>
        <div style=\"font-size:28px;font-weight:700;letter-spacing:4px;margin:12px 0\">$safeOtp</div>
        <p>This code expires in <b>$safeMinutes minutes</b>.</p>
        <p>If you did not request this, you can ignore this email.</p>
      </div>
    ";
    $mail->AltBody = "Admin PIN Reset OTP: $otp (expires in $safeMinutes minutes)";

    try {
        $mail->send();
    } catch (Throwable $e) {
        http_response_code(500);
        echo json_encode([
            'success' => false,
            'error' => 'Failed to send OTP email.',
        ]);
        exit;
    }
}

