-- Copy this file to secrets.lua (same folder) and fill in your own values.
-- secrets.lua is listed in .gitignore — never commit your real token.
--
-- Use a GitHub *fine-grained* Personal Access Token scoped to ONLY this one
-- repository, with just "Contents: Read and write" permission. Do not use a
-- classic token with broad account access, especially on a handheld.
return {
  owner  = "your-github-username",
  repo   = "your-repo-name",
  branch = "main",
  path   = "minoru/persona.json", -- where inside the repo to write the file
  token  = "github_pat_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
}
