#!/usr/bin/perl
#
# ***** BEGIN LICENSE BLOCK *****
# Zimbra Collaboration Suite Server
# Copyright (C) 2011 Zimbra, Inc.
#
# The contents of this file are subject to the Zimbra Public License
# Version 1.3 ("License"); you may not use this file except in
# compliance with the License.  You may obtain a copy of the License at
# http://www.zimbra.com/license.
#
# Software distributed under the License is distributed on an "AS IS"
# basis, WITHOUT WARRANTY OF ANY KIND, either express or implied.
# ***** END LICENSE BLOCK *****
#

use strict;
use Migrate;

########################################################################################################################

Migrate::verifySchemaVersion(69);

foreach my $group (Migrate::getMailboxGroups()) {
  addTagTable($group);
  addTaggedItemTable($group);
  addTagNamesColumn($group);
  # can't drop indexes until *after* migration is complete
#  dropTagIndexes($group);
}

Migrate::updateSchemaVersion(69, 70);

exit(0);

########################################################################################################################

sub addTagTable($) {
  my ($group) = @_;

  my $sql = <<_EOF_;
CREATE TABLE IF NOT EXISTS $group.tag (
   mailbox_id    INTEGER UNSIGNED NOT NULL,
   id            INTEGER NOT NULL,
   name          VARCHAR(128) NOT NULL,
   color         BIGINT,
   item_count    INTEGER NOT NULL DEFAULT 0,
   unread        INTEGER NOT NULL DEFAULT 0,
   listed        BOOLEAN NOT NULL DEFAULT FALSE,
   sequence      INTEGER UNSIGNED NOT NULL,  -- change number for rename/recolor/etc.
   policy        VARCHAR(1024),

   PRIMARY KEY (mailbox_id, id),
   UNIQUE INDEX i_tag_name (mailbox_id, name),
   CONSTRAINT fk_tag_mailbox_id FOREIGN KEY (mailbox_id) REFERENCES zimbra.mailbox(id)
) ENGINE = InnoDB;
_EOF_

  Migrate::logSql("Adding $group.TAG table...");
  Migrate::runSql($sql);
}

sub addTaggedItemTable($) {
  my ($group) = @_;

  my $sql = <<_EOF_;
CREATE TABLE IF NOT EXISTS $group.tagged_item (
   mailbox_id    INTEGER UNSIGNED NOT NULL,
   tag_id        INTEGER NOT NULL,
   item_id       INTEGER UNSIGNED NOT NULL,

   UNIQUE INDEX i_tagged_item_unique (mailbox_id, tag_id, item_id),
   CONSTRAINT fk_tagged_item_tag FOREIGN KEY (mailbox_id, tag_id) REFERENCES $group.tag(mailbox_id, id) ON DELETE CASCADE,
   CONSTRAINT fk_tagged_item_item FOREIGN KEY (mailbox_id, item_id) REFERENCES $group.mail_item(mailbox_id, id) ON DELETE CASCADE
) ENGINE = InnoDB;
_EOF_

  Migrate::logSql("Adding $group.TAGGED_ITEM table...");
  Migrate::runSql($sql);
}

sub addTagNamesColumn($) {
  my ($group) = @_;

  my $sql = <<_EOF_;
ALTER TABLE $group.mail_item ADD COLUMN tag_names TEXT AFTER tags;
ALTER TABLE $group.mail_item_dumpster ADD COLUMN tag_names TEXT AFTER tags;
_EOF_

  Migrate::logSql("Adding TAG_NAMES column to $group.MAIL_ITEM and $group.MAIL_ITEM_DUMPSTER...");
  Migrate::runSql($sql);
}

sub dropTagIndexes($) {
  my ($group) = @_;

  my $sql = <<_EOF_;
ALTER TABLE $group.mail_item DROP INDEX i_unread;
ALTER TABLE $group.mail_item DROP INDEX i_tags_date;
ALTER TABLE $group.mail_item DROP INDEX i_flags_date;
ALTER TABLE $group.mail_item_dumpster DROP INDEX i_unread;
ALTER TABLE $group.mail_item_dumpster DROP INDEX i_tags_date;
ALTER TABLE $group.mail_item_dumpster DROP INDEX i_flags_date;
_EOF_

  Migrate::logSql("Dropping tag/flag/unread indexes from $group.MAIL_ITEM and $group.MAIL_ITEM_DUMPSTER...");
  Migrate::runSql($sql);
}
