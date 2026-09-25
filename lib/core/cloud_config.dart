/// Supabase project the app talks to (for Alexa). Both values are public by
/// design: access is controlled by row-level security and the edge functions,
/// so they're safe to commit. Leave empty to hide the Alexa feature.
///
/// Supabase dashboard -> Project Settings -> API: "Project URL" and the
/// "publishable" key (older projects: "anon").
const supabaseUrl = '';
const supabasePublishableKey = '';

bool get cloudConfigured => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
