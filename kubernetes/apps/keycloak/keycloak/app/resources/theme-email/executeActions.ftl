<#-- Sent when an admin creates an account (Update Password) or asks for other account actions -->
<#import "template.ftl" as layout>
<#assign actions = requiredActions![]>
<#assign isNewAccount = actions?seq_contains("UPDATE_PASSWORD")>
<#assign actionList><#list actions as a>${msg("requiredAction.${a}")}<#sep><#if a?index == actions?size - 2> and <#else>, </#if></#sep></#list></#assign>
<#assign greeting><#if (user.firstName)?has_content>Hi ${user.firstName},<#else>Hi,</#if></#assign>
<@layout.emailLayout>
<#if isNewAccount>
<@layout.heading text="Set up your Chillincool account"/>
<p style="margin:0 0 16px;">${greeting}</p>
<p style="margin:0 0 16px;">Chris created a Chillincool account for you. It's one login for everything Chris shares with you.</p>
<p style="margin:0 0 16px;">Click the button to ${actionList}.<#if actions?seq_contains("CONFIGURE_TOTP")> You'll need an authenticator app on your phone for the authenticator step<#else> Right after that, you'll set up an authenticator app, so have one installed on your phone first</#if> (Google Authenticator, Microsoft Authenticator, or the iPhone Passwords app).</p>
<#else>
<@layout.heading text="Update your Chillincool account"/>
<p style="margin:0 0 16px;">${greeting}</p>
<p style="margin:0 0 16px;">Chris asked you to ${actionList} on your Chillincool account. Click the button to do it now.</p>
</#if>
<@layout.button href=link label=isNewAccount?then("Set up my account", "Update my account")/>
<p style="margin:0 0 16px;">This link works for ${linkExpirationFormatter(linkExpiration)}. If it has expired, ask Chris to send a new one.</p>
<@layout.fallbackLink href=link/>
<p style="margin:0;font-size:13px;color:#6b7280;">Weren't expecting this? You can ignore it and nothing will change.</p>
</@layout.emailLayout>
