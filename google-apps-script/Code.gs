/**
 * AI Personal App - Google Apps Script gateway.
 * Configure Script Properties: PROVIDER_API_KEY, GATEWAY_TOKEN, PROVIDER_BASE_URL, PROVIDER_MODEL
 * Deploy as Web app (execute as you, access according to your security needs).
 */
const PROP = PropertiesService.getScriptProperties();
function doGet(e) {
  const action = (e && e.parameter && e.parameter.action) || "health";
  if (action === "health") return json({ok:true, service:"AI Apps Script Gateway"});
  if (!auth_(e)) return json({error:"Unauthorized"},401);
  if (action === "models") return json({data:[{id:PROP.getProperty("PROVIDER_MODEL")||"configured-model"}]});
  return json({error:"Unknown action"},400);
}
function doPost(e) {
  if (!auth_(e)) return json({error:"Unauthorized"},401);
  let body;
  try { body = JSON.parse((e && e.postData && e.postData.contents) || "{}"); }
  catch (_) { return json({error:"Invalid JSON"},400); }
  if (body.action === "models") return json({data:[{id:PROP.getProperty("PROVIDER_MODEL")||"configured-model"}]});
  if (body.action !== "chat") return json({error:"Expected action=chat"},400);
  if (!Array.isArray(body.messages) || !body.messages.length) return json({error:"messages required"},400);
  const key=PROP.getProperty("PROVIDER_API_KEY"), model=body.model||PROP.getProperty("PROVIDER_MODEL");
  if (!key || !model) return json({error:"Gateway is not configured"},503);
  const url=(PROP.getProperty("PROVIDER_BASE_URL")||"https://api.openai.com/v1").replace(/\/$/,"")+"/chat/completions";
  try {
    const r=UrlFetchApp.fetch(url,{method:"post",contentType:"application/json",
      headers:{Authorization:"Bearer "+key},payload:JSON.stringify({model:model,messages:body.messages,stream:false}),
      muteHttpExceptions:true});
    const code=r.getResponseCode(), text=r.getContentText();
    if(code<200||code>=300) return json({error:"Provider request failed",detail:text.slice(0,1500)},code);
    const parsed=JSON.parse(text);
    const answer=parsed.choices && parsed.choices[0] && parsed.choices[0].message && parsed.choices[0].message.content;
    return json({answer:answer||"",usage:parsed.usage||null});
  } catch(err) { return json({error:"Gateway error",detail:String(err)},502); }
}
function auth_(e) {
  const expected=PROP.getProperty("GATEWAY_TOKEN");
  if(!expected) return false;
  const supplied=(e && e.parameter && e.parameter.token)||"";
  return supplied===expected;
}
function json(obj,code) {
  // Apps Script ContentService cannot reliably set arbitrary HTTP status codes.
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
