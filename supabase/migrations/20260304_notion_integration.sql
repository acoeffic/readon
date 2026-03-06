-- Migration: Notion integration
-- OAuth tokens + workspace info sur profiles, tracking sync sur user_books

-- profiles: Notion OAuth credentials
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notion_access_token TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notion_workspace_id TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notion_workspace_name TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notion_database_id TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS notion_connected_at TIMESTAMPTZ;

COMMENT ON COLUMN profiles.notion_access_token IS
  'Notion OAuth access token (used only by edge functions via service_role, never exposed to client)';

-- user_books: track synced reading sheet pages
ALTER TABLE user_books ADD COLUMN IF NOT EXISTS notion_page_id TEXT;
ALTER TABLE user_books ADD COLUMN IF NOT EXISTS notion_synced_at TIMESTAMPTZ;
