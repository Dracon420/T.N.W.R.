// T.N.W.R. Alexa skill (Alexa-hosted, Node.js).
//
// - "Alexa, ask naggy wife to link code 482173": links this Echo to the app.
// - The app's backend (supabase/functions/alexa-sync) sends the upcoming
//   reminders as a Messaging.MessageReceived request. This skill turns each
//   into a series of Alexa reminders (at the due time, then every few minutes)
//   and deletes the rest once the task is proven done in the app.
// - "Alexa, ask naggy wife what's due": reads out upcoming reminders.
const Alexa = require('ask-sdk-core');
const { S3PersistenceAdapter } = require('ask-sdk-s3-persistence-adapter');
const https = require('https');
const config = require('./config');

const REMINDERS_SCOPE = 'alexa::alerts:reminders:skill:readwrite';

// ---------- helpers ----------

function postJson(url, body, headers) {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify(body);
    const req = https.request(url, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'content-length': Buffer.byteLength(data), ...headers },
      timeout: 5000,
    }, (res) => {
      let text = '';
      res.on('data', (c) => { text += c; });
      res.on('end', () => resolve({ status: res.statusCode, text }));
    });
    req.on('error', reject);
    req.on('timeout', () => req.destroy(new Error('timeout')));
    req.end(data);
  });
}

function hasRemindersPermission(handlerInput) {
  const user = handlerInput.requestEnvelope.context.System.user;
  return Boolean(user.permissions && user.permissions.consentToken);
}

function askForReminders(handlerInput, speech) {
  return handlerInput.responseBuilder
    .speak(speech)
    .addDirective({
      type: 'Connections.SendRequest',
      name: 'AskFor',
      payload: {
        '@type': 'AskForPermissionsConsentRequest',
        '@version': '2',
        permissionScopes: [{ permissionScope: REMINDERS_SCOPE, consentLevel: 'ACCOUNT' }],
      },
      token: '',
    })
    .getResponse();
}

/** "2026-09-25T20:00:00" (the phone's local time) plus minutes, same format. */
function addMinutes(local, minutes) {
  const d = new Date(`${local}Z`);
  d.setUTCMinutes(d.getUTCMinutes() + minutes);
  return d.toISOString().slice(0, 19);
}

function sayTime(local) {
  const d = new Date(`${local}Z`);
  const h = d.getUTCHours();
  const m = d.getUTCMinutes();
  const hour = h % 12 === 0 ? 12 : h % 12;
  const mins = m === 0 ? '' : `:${String(m).padStart(2, '0')}`;
  return `${hour}${mins} ${h < 12 ? 'AM' : 'PM'}`;
}

function reminderBody(title, when, repeatIndex) {
  const text = repeatIndex === 0
    ? `Time to ${title}.`
    : `Still waiting on: ${title}. Prove it's done in the app to stop these reminders.`;
  return {
    requestTime: new Date().toISOString().slice(0, 19),
    // No timeZoneId: Alexa uses this Echo's time zone, matching the phone's local time.
    trigger: { type: 'SCHEDULED_ABSOLUTE', scheduledTime: when },
    alertInfo: { spokenInfo: { content: [{ locale: 'en-US', text }] } },
    pushNotification: { status: 'ENABLED' },
  };
}

async function deleteReminders(client, ids) {
  await Promise.all((ids || []).map((id) =>
    client.deleteReminder(id).catch(() => { /* already played or deleted */ })));
}

// ---------- handlers ----------

const LaunchHandler = {
  canHandle: (h) => Alexa.getRequestType(h.requestEnvelope) === 'LaunchRequest',
  async handle(h) {
    const attrs = (await h.attributesManager.getPersistentAttributes()) || {};
    if (!attrs.linked) {
      return h.responseBuilder
        .speak('Welcome to Naggy Wife. To connect your app, open it, go to Settings, tap Connect Alexa, '
          + 'then tell me the six digit code. For example, say: link code, one two three four five six.')
        .reprompt('What is your six digit code?')
        .getResponse();
    }
    if (!hasRemindersPermission(h)) {
      return askForReminders(h, 'You are linked, but I need permission to set reminders on this device.');
    }
    return h.responseBuilder.speak(dueSummary(attrs)).getResponse();
  },
};

const LinkHandler = {
  canHandle: (h) => Alexa.getRequestType(h.requestEnvelope) === 'IntentRequest'
    && Alexa.getIntentName(h.requestEnvelope) === 'LinkIntent',
  async handle(h) {
    const code = Alexa.getSlotValue(h.requestEnvelope, 'code');
    if (!code || !/^\d{6}$/.test(code)) {
      return h.responseBuilder
        .speak("I didn't catch a six digit code. Please say: link code, followed by the six digits in the app.")
        .reprompt('What is your six digit code?')
        .getResponse();
    }
    const userId = Alexa.getUserId(h.requestEnvelope);
    let res;
    try {
      res = await postJson(`${config.SUPABASE_URL}/functions/v1/alexa-pair`,
        { code, alexaUserId: userId }, { 'x-pair-secret': config.PAIR_SECRET });
    } catch (e) {
      console.log('pair request failed', e);
      return h.responseBuilder.speak("I couldn't reach the app's server. Please try again in a minute.").getResponse();
    }
    if (res.status !== 200) {
      console.log('pair rejected', res.status, res.text);
      return h.responseBuilder
        .speak("That code didn't work. Codes expire after ten minutes, so get a new one in the app and try again.")
        .getResponse();
    }
    const attrs = (await h.attributesManager.getPersistentAttributes()) || {};
    attrs.linked = true;
    h.attributesManager.setPersistentAttributes(attrs);
    await h.attributesManager.savePersistentAttributes();

    if (!hasRemindersPermission(h)) {
      return askForReminders(h, 'Linked! Next, I need permission to set reminders, so I can nag you when something is due.');
    }
    return h.responseBuilder.speak("Linked! I'll remind you on this device until each task is done.").getResponse();
  },
};

const PermissionResponseHandler = {
  canHandle: (h) => Alexa.getRequestType(h.requestEnvelope) === 'Connections.Response',
  handle(h) {
    const status = h.requestEnvelope.request.payload && h.requestEnvelope.request.payload.status;
    const speech = status === 'ACCEPTED'
      ? "Thanks! Your reminders will now play on this device until you prove they're done in the app."
      : "Okay. Without reminder permission I can't nag you on this device. You can allow it later in the Alexa app, under this skill's settings.";
    return h.responseBuilder.speak(speech).getResponse();
  },
};

function dueSummary(attrs) {
  const tasks = Object.values(attrs.tasks || {}).sort((a, b) => a.at.localeCompare(b.at));
  if (tasks.length === 0) return "You're all caught up. Nothing is due.";
  const first = tasks.slice(0, 3).map((t) => `${t.title} at ${sayTime(t.at)}`);
  const more = tasks.length > 3 ? `, and ${tasks.length - 3} more` : '';
  return `You have ${tasks.length} reminder${tasks.length === 1 ? '' : 's'}: ${first.join(', ')}${more}.`;
}

const WhatsDueHandler = {
  canHandle: (h) => Alexa.getRequestType(h.requestEnvelope) === 'IntentRequest'
    && Alexa.getIntentName(h.requestEnvelope) === 'WhatsDueIntent',
  async handle(h) {
    const attrs = (await h.attributesManager.getPersistentAttributes()) || {};
    if (!attrs.linked) {
      return h.responseBuilder.speak("You're not linked yet. Open the app, go to Settings, and tap Connect Alexa.").getResponse();
    }
    return h.responseBuilder.speak(dueSummary(attrs)).getResponse();
  },
};

/**
 * From alexa-sync: {tasks: [{id, title, at, everyMin, count}]} is the full
 * list of upcoming tasks. Makes the Echo's reminders match it.
 */
const MessageHandler = {
  canHandle: (h) => Alexa.getRequestType(h.requestEnvelope) === 'Messaging.MessageReceived',
  async handle(h) {
    const tasks = (h.requestEnvelope.request.message && h.requestEnvelope.request.message.tasks) || [];
    const attrs = (await h.attributesManager.getPersistentAttributes()) || {};
    const known = attrs.tasks || {};
    const client = h.serviceClientFactory.getReminderManagementServiceClient();
    const next = {};

    for (const t of tasks) {
      const sig = JSON.stringify([t.title, t.at, t.everyMin, t.count]);
      if (known[t.id] && known[t.id].sig === sig) {
        next[t.id] = known[t.id];
        continue;
      }
      if (known[t.id]) await deleteReminders(client, known[t.id].ids);
      const results = await Promise.all(Array.from({ length: t.count }, (_, i) =>
        client.createReminder(reminderBody(t.title, addMinutes(t.at, i * t.everyMin), i))
          .then((r) => r.alertToken)
          .catch((e) => { console.log('create failed', t.id, i, e.message); return null; })));
      next[t.id] = { sig, ids: results.filter(Boolean), title: t.title, at: t.at };
    }
    // Tasks no longer in the list were proven done (or deleted): stop nagging.
    for (const id of Object.keys(known)) {
      if (!next[id]) await deleteReminders(client, known[id].ids);
    }

    attrs.tasks = next;
    h.attributesManager.setPersistentAttributes(attrs);
    await h.attributesManager.savePersistentAttributes();
    return h.responseBuilder.getResponse();
  },
};

const HelpHandler = {
  canHandle: (h) => Alexa.getRequestType(h.requestEnvelope) === 'IntentRequest'
    && Alexa.getIntentName(h.requestEnvelope) === 'AMAZON.HelpIntent',
  handle: (h) => h.responseBuilder
    .speak('I play your T N W R reminders on this device, and keep repeating them until you prove the task is done in the app. '
      + 'You can say: what\'s due. Or, to connect the app, say: link code, followed by the six digit code from the app.')
    .reprompt('What would you like to do?')
    .getResponse(),
};

const StopHandler = {
  canHandle: (h) => Alexa.getRequestType(h.requestEnvelope) === 'IntentRequest'
    && ['AMAZON.CancelIntent', 'AMAZON.StopIntent', 'AMAZON.NavigateHomeIntent']
      .includes(Alexa.getIntentName(h.requestEnvelope)),
  handle: (h) => h.responseBuilder.speak('Okay.').getResponse(),
};

const FallbackHandler = {
  canHandle: (h) => Alexa.getRequestType(h.requestEnvelope) === 'IntentRequest'
    && Alexa.getIntentName(h.requestEnvelope) === 'AMAZON.FallbackIntent',
  handle: (h) => h.responseBuilder
    .speak("Sorry, I didn't get that. You can say: what's due, or link code followed by your six digit code.")
    .reprompt('What would you like to do?')
    .getResponse(),
};

const SessionEndedHandler = {
  canHandle: (h) => Alexa.getRequestType(h.requestEnvelope) === 'SessionEndedRequest',
  handle: (h) => h.responseBuilder.getResponse(),
};

const ErrorHandler = {
  canHandle: () => true,
  handle(h, error) {
    console.log('error', error);
    return h.responseBuilder.speak('Sorry, something went wrong. Please try again.').getResponse();
  },
};

exports.handler = Alexa.SkillBuilders.custom()
  .addRequestHandlers(
    MessageHandler,
    LaunchHandler,
    LinkHandler,
    PermissionResponseHandler,
    WhatsDueHandler,
    HelpHandler,
    StopHandler,
    FallbackHandler,
    SessionEndedHandler,
  )
  .addErrorHandlers(ErrorHandler)
  .withApiClient(new Alexa.DefaultApiClient())
  .withPersistenceAdapter(new S3PersistenceAdapter({ bucketName: process.env.S3_PERSISTENCE_BUCKET }))
  .lambda();
