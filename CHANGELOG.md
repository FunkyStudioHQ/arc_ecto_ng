# Changelog

## v0.2.0 (2018-03-27)
Started the fork from original [arc_ecto](https://github.com/stavro/arc_ecto):

* (API Change) Use `Changeset.prepare_changes/2` to upload when all is valid
* (API Change) Use `handle_attachments/4` in changeset
* (Enhancement) Use `NaiveDateTime` instead of `Ecto.DateTime`.
* (Dependency Update) Require `ecto ~> 2.1`
