# /packages/intranet-filestorage/www/upload-2.tcl
#
# Copyright (C) 2003 - 2009 ]project-open[
#
# All rights reserved. Please check
# https://www.project-open.com/license/ for details.

ad_page_contract {
    insert a file into the file system

    @author frank.bergmann@project-open.com
} {
    folder_type
    bread_crum_path
    object_id:integer
    return_url
    upload_file
    {file_title:trim ""}
    {description ""}
} 

set user_id [auth::require_login]
set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
set page_title "Upload into '$bread_crum_path'"
set context_bar [im_context_bar [list "/intranet/projects/" "Projects"]  [list "/intranet/projects/view?group_id=$object_id" "One Project"]  "Upload File"]

if { "" == $upload_file } { ad_return_complaint xx "Please choose a file to upload" }

# Get the list of all relevant roles and profiles for permissions
set roles [im_filestorage_roles $user_id $object_id]
set profiles [im_filestorage_profiles $user_id $object_id]

# Get the group membership of the current (viewing) user
set user_memberships [im_filestorage_user_memberships $user_id $object_id]

# Get the list of all (known) permission of all folders of the FS
# of the current object
set perm_hash_array [im_filestorage_get_perm_hash $user_id $object_id $user_memberships]
array set perm_hash $perm_hash_array


# Check bread_crum_path
set bread_crum_list [split $bread_crum_path "/"]
set bread_crum_list_checked [list]
foreach bc $bread_crum_list {
    if {".." == $bc} {
	im_security_alert \
	    -location im_filestorage_base_component \
	    -message "Break-in attempt" \
	    -value $bc \
	    -severity "Serious"
	continue
    }
    lappend bread_crum_list_checked $bc
}
set bread_crum_list $bread_crum_list_checked
set bread_crum_path [join $bread_crum_list_checked "/"]


# Check permissions and skip
set user_perms [im_filestorage_folder_permissions $user_id $object_id $bread_crum_path $user_memberships $roles $profiles $perm_hash_array]
set write_p [lindex $user_perms 2]
if {!$write_p} {
    ad_return_complaint 1 "You don't have permission to write to folder '$bread_crum_path'"
    return
}


# -------------------- Check the user input first ----------------------------
#
set exception_text ""
set exception_count 0
if {"" == $folder_type} {
    append exception_text "<LI>Internal Error: folder_type not specified"
    incr exception_count
}
if { $exception_count > 0 } {
    ad_return_complaint $exception_count $exception_text
    return 0
}

# Get the file from the user.
# number_of_bytes is the upper-limit
set max_n_bytes [im_parameter -package_id [im_package_filestorage_id] MaxNumberOfBytes "" 0]
set tmp_filename [ns_queryget upload_file.tmpfile]
if { 0 == [file size $tmp_filename] } {
    ad_return_complaint 1 [lang::message::lookup "" intranet-filestorage.FileNotFound "You did not select a file or the file you are trying to upload is empty."]
    ad_script_abort
}
im_security_alert_check_tmpnam -location "upload-2" -value $tmp_filename
ns_log Notice "upload-2: tmp_filename=$tmp_filename"

if { $max_n_bytes && ([file size $tmp_filename] > $max_n_bytes) } {
    ad_return_complaint 1 "Your file is larger than the maximum permissible upload size:  [util_commify_number $max_n_bytes] bytes"
    return 0
}

set file_extension [string tolower [file extension $upload_file]]
# remove the first . from the file extension
regsub "\." $file_extension "" file_extension
set guessed_file_type [ns_guesstype $upload_file]
set n_bytes [file size $tmp_filename]

# strip off the C:\directories... crud and just get the file name
if {![regexp {([^//\\]+)$} $upload_file match client_filename]} {
    # couldn't find a match
    set client_filename $upload_file
}

if {[regexp {\.\.} $client_filename]} {
    set error "<li>Path contains forbidden characters<br>
    Please don't use '.' characters."
    ad_return_complaint "User Error" $error
}

# ---------- Check for charset compliance -----------

set hint ""
set filename $client_filename
set charset [im_parameter -package_id [im_package_filestorage_id] FilenameCharactersSupported "" "alphanum"]

if {![im_filestorage_check_filename $charset $filename]} {
    if { "utf8" != $charset } {
	set hint [lang::message::lookup "" intranet-filestorage.Invalid_Character_SetHint. "Please contact your SysAdministrator. Most likely this problem can be resolved by setting parameter 'FilenameCharactersSupported' to 'utf8'"]
    }

    ad_return_complaint 1 "[lang::message::lookup "" intranet-filestorage.Invalid_Character_Set "
                <b>Invalid Character(s) found</b>:<br>
                Your filename '%filename%' contains atleast one character that is not allowed
                in your character set '%charset%'."]<br>$hint" 
    ad_script_abort
}


# ---------- Determine the location where to save the file -----------


set base_path [im_filestorage_base_path $folder_type $object_id]
if {"" == $base_path} {
    ad_return_complaint 1 "<LI>Unknown folder type \"$folder_type\"."
    return
}
set dest_path "$base_path/$bread_crum_path/$client_filename"


# --------------- Let's copy the file into the FS --------------------

ns_log Notice "dest_path=$dest_path"

if { [catch {
    file copy -force -- $tmp_filename $dest_path
    ns_log Notice "chmod ug+w $dest_path"
    im_exec chmod ug+w $dest_path
} err_msg] } {
    # Probably some permission errors
    ad_return_complaint  "Error writing upload file"  $err_msg
    return
}


# --------------- Log the interaction --------------------

db_dml insert_action "
insert into im_fs_actions (
        action_type_id,
        user_id,
        action_date,
        file_name
) values (
        [im_file_action_upload],
        :user_id,
        now(),
        :dest_path || '/' || :client_filename
)"



set page_content "
<H2>Upload Successful</H2>

You have successfully uploaded $n_bytes bytes of '$client_filename'.<br>
You can now return to the project page.
<P>

<A href=\"$return_url\">Return to Previous Page</a>

"

set page_content "
<div id=\"slave\">
<div id=\"slave_content\">
<!-- intranet/www/po-master.adp before slave -->
$page_content
<!-- intranet/www/po-master.adp after slave -->
</div>
</div>
"


db_release_unused_handles
doc_return  200 text/html [im_return_template]
