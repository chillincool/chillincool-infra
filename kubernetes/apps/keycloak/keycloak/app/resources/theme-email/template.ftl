<#-- Layout shared by every chillincool email. Email clients ignore <style> blocks and SVG, so
     everything is inline styles and tables, and the banner (a still of the login page's rings
     behind the logo) is a PNG hosted on the blog. -->
<#macro emailLayout>
<html lang="${locale.language}" dir="${(ltr)?then('ltr','rtl')}">
<body style="margin:0;padding:0;background:#eceef1;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#eceef1;">
  <tr>
    <td align="center" style="padding:32px 16px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;">
        <tr>
          <td align="center" style="background:#0b0b0b;border-radius:12px 12px 0 0;line-height:0;font-size:0;">
            <img src="https://blog.chillincool.net/static/email/chillincool-banner.png" width="560" alt="CHILLINCOOL" style="display:block;width:100%;max-width:560px;height:auto;border:0;border-radius:12px 12px 0 0;color:#ffffff;font-family:'Segoe UI',Helvetica,Arial,sans-serif;font-size:18px;line-height:1.4;letter-spacing:0.28em;">
          </td>
        </tr>
        <tr>
          <td style="background:#ffffff;border-radius:0 0 12px 12px;padding:32px 32px 28px;font-family:'Segoe UI',Helvetica,Arial,sans-serif;font-size:16px;line-height:1.6;color:#1d2129;">
            <#nested>
          </td>
        </tr>
        <tr>
          <td align="center" style="padding:20px 24px 0;font-family:'Segoe UI',Helvetica,Arial,sans-serif;font-size:13px;line-height:1.5;color:#6b7280;">
            Sent by the Chillincool account system. Questions? Reply to Chris directly, not to this email.
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>
</#macro>

<#macro button href label>
<table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:24px 0;">
  <tr>
    <td style="background:#141414;border-radius:8px;">
      <a href="${href}" style="display:inline-block;padding:14px 26px;font-family:'Segoe UI',Helvetica,Arial,sans-serif;font-size:16px;font-weight:600;color:#ffffff;text-decoration:none;">${label}</a>
    </td>
  </tr>
</table>
</#macro>

<#macro heading text>
<h1 style="margin:0 0 16px;font-family:'Outfit','Segoe UI',Helvetica,Arial,sans-serif;font-size:24px;line-height:1.3;font-weight:700;color:#141414;">${text}</h1>
</#macro>

<#macro fallbackLink href>
<p style="margin:0 0 16px;font-size:13px;color:#6b7280;">If the button doesn't work, copy this address into your browser:<br><a href="${href}" style="color:#4b5563;word-break:break-all;">${href}</a></p>
</#macro>
