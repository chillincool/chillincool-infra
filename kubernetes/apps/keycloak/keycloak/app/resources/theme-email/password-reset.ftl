<#-- Sent when someone clicks "Forgot Password?" on the sign-in page -->
<#import "template.ftl" as layout>
<#assign greeting><#if (user.firstName)?has_content>Hi ${user.firstName},<#else>Hi,</#if></#assign>
<@layout.emailLayout>
<@layout.heading text="Reset your password"/>
<p style="margin:0 0 16px;">${greeting}</p>
<p style="margin:0 0 16px;">Someone asked to reset the password for your Chillincool account. If that was you, click the button to choose a new one.</p>
<@layout.button href=link label="Reset my password"/>
<p style="margin:0 0 16px;">This link works for ${linkExpirationFormatter(linkExpiration)}.</p>
<@layout.fallbackLink href=link/>
<p style="margin:0;font-size:13px;color:#6b7280;">Didn't ask for this? You can ignore this email. Your password stays the same.</p>
</@layout.emailLayout>
