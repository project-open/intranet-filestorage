# /packages/intranet-filestorage/action.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    Single point of entry for all FS related actions.
    We need this, because we are using form buttons
    instead of JavaScript, so that there is only a
    single target for the form.

    @param submit (up-folder, new-folder, upload, new-doc, del, zip)

    @author pvilarmau@hotmail.com
    @author santitrenchs@santitrenchs.com
    @author frank.bergmann@project-open.com
} {
    actions
    file_id:array,optional
    dir_id:array,optional
    id_path:array,optional
    bread_crum_path
    object_id:notnull
    folder_type
    return_url:notnull
}

# User id already verified by filters
set user_id [ad_maybe_redirect_for_registration]
set base_path [im_filestorage_base_path $folder_type $object_id]


set url_base_list [split $return_url "?"]
set url_base [lindex $url_base_list 0]
set bgcolor(0) " class=roweven "
set bgcolor(1) " class=rowodd "

# Remove those variables that we've extracted in the
# page contract. Why?
set bind_vars [ns_conn form]
ns_set delkey $bind_vars bread_crum_path
ns_set delkey $bind_vars actions
ns_set delkey $bind_vars return_url

# X and Y come from image buttons and can just
# be removed
ns_set delkey $bind_vars x
ns_set delkey $bind_vars y


foreach var [ad_ns_set_keys $bind_vars] {
    set value [ns_set get $bind_vars $var]
    if {[regexp {first_line_flag} $var]} {
	ns_set delkey $bind_vars $var
    }
}

set vars ""

switch $actions {
    "none" {

	# --------------------- None --------------------- 

	ad_returnredirect $return_url
    }

    "add-perms" {

	# --------------------- Add permissions to folders --------------------- 

	set profiles [im_filestorage_profiles $user_id $object_id]
	set roles [im_filestorage_roles $user_id $object_id]
	set tds [im_filestorage_profile_tds $user_id $object_id]
	set num_profiles [expr [llength $roles] + [llength $profiles]]

        set dirs_html ""
	set ctr 0
        foreach id [array names dir_id] {
            set rel_path $id_path($id)
            set abs_path "$base_path/$rel_path"
            set checked "checked"
            incr ctr
            append dirs_html "
<tr $bgcolor([expr $ctr % 2])>
  <td>
    <input type=checkbox name=dir_id.$id $checked>
    <input type=hidden name=id_path.$id value=\"$id_path($id)\">
  </td>
  <td>$id_path($id)</td>
</tr>\n"
        }

	set page_title "Add Permissions"
	set page_content "
<H1>$page_title</H1>
<form action=/intranet-filestorage/add-perms-2 method=POST>
[export_form_vars object_id folder_type bread_crum_path return_url]
<table border=0 cellspacing=0 cellpadding=2>
<tr class=rowtitle>
  <td></td>
  $tds
</tr>
<tr class=roweven>
  <td>View</td>\n"
	foreach role $roles {
	    set role_id [lindex $role 0]
	    append page_content "<td><input type=checkbox name=view_role.$role_id</td>\n"
	}
	foreach profile $profiles {
	    set profile_id [lindex $profile 0]
	    append page_content "<td><input type=checkbox name=view_profile.$profile_id</td>\n"
	}
	append page_content "
</tr>
<tr class=rowodd>
  <td>Read</td>\n"
	foreach role $roles {
	    set role_id [lindex $role 0]
	    append page_content "<td><input type=checkbox name=read_role.$role_id</td>\n"
	}
	foreach profile $profiles {
	    set profile_id [lindex $profile 0]
	    append page_content "<td><input type=checkbox name=read_profile.$profile_id</td>\n"
	}
	append page_content "
</tr>
<tr class=roweven>
  <td>Write</td>\n"
	foreach role $roles {
	    set role_id [lindex $role 0]
	    append page_content "<td><input type=checkbox name=write_role.$role_id</td>\n"
	}
	foreach profile $profiles {
	    set profile_id [lindex $profile 0]
	    append page_content "<td><input type=checkbox name=write_profile.$profile_id</td>\n"
	}
	append page_content "
</tr>
<tr class=rowodd>
  <td>Admin</td>\n"
	foreach role $roles {
	    set role_id [lindex $role 0]
	    append page_content "<td><input type=checkbox name=admin_role.$role_id</td>\n"
	}
	foreach profile $profiles {
	    set profile_id [lindex $profile 0]
	    append page_content "<td><input type=checkbox name=admin_profile.$profile_id</td>\n"
	}
	append page_content "
</tr>
</table>
<P>
<input type=submit name=submit value=\"Add Permissions\">
Add the permissions above to the following directories:</p>

<table border=0 cellspacing=0 cellpadding=1>
<tr class=rowtitle><td colspan=2 class=rowtitle>Directories</td></tr>
$dirs_html
</table>
</form>
<p>\n"

	if {"" == $dirs_html} {
	    set page_content "
<H1>No Directories Selected</H1>
You have not selected a directory.<p>
Please backup, select a directory and press again on the [im_gif plus_9] button.<p>
"
	}

        doc_return  200 text/html [im_return_template]
        return

    }

    "zip" {

	# --------------------- Download a ZIP --------------------- 

	# Find out where the current directory starts on the hard disk
	set base_path [im_filestorage_base_path $folder_type $object_id]
	if {"" == $base_path} {
	    ad_return_complaint 1 "<LI>Unknown folder type \"$folder_type\"."
	    return
	}
	set dest_path "$base_path/$bread_crum_path"

	# Determine a random .tgz file
	set r [ns_rand 10000000]
	set file "zip.$user_id.$r.tgz"
	ns_log Notice "file=$file"
	set path "/tmp/$file"
	ns_log Notice "/bin/tar czf $path $dest_path"
	
	if { [catch {
	    exec /bin/tar czf $path $dest_path
	} err_msg] } {
	    # Nothing. We check if TAR was successfull if the file exists.
	}

	if { [catch {
	    set file_readable [file readable $path]
	} err_msg] } {
	    ad_return_complaint 1 "<LI>Unable to compress the folder."
	    return
	}

	if $file_readable {
	    ad_returnredirect "/intranet/download/zip/0/$file"
	    return
	} else {
	    doc_return 404 text/html "Did not find the specified file"
	    return
	}
    }

    "new-folder" {

	# --------------------- New Folder --------------------- 

        set page_title "New Folder"
        set context_bar [ad_context_bar $page_title]
	set page_content "
<h1>New Folder</h1>
<form method='post' action='create-folder-2'>
[export_form_vars folder_type bread_crum_path object_id return_url]
<table><tr><td>Please enter the name of the new folder
</td></tr>
<tr><td>
  <input type='text' name='folder_name' value='' style='width: 100%;'>
  <input type='submit' value='create folder'>
</td></tr>
</table>
</form>\n"
	doc_return  200 text/html [im_return_template]
	return
    }

    "upload" {

	# --------------------- New Folder --------------------- 

        set page_title "Upload File"
        set context_bar [ad_context_bar $page_title]
        set page_content "
<form enctype=multipart/form-data method=POST action=upload-2.tcl>
[export_form_vars bread_crum_path folder_type object_id return_url]

          Upload a file into directory \"/$bread_crum_path\".
          If you want to upload a file into a subdirectory, <br>
          please backup up and select a subdirectory by clicking on its name.

    <table border=0>
      <tr>
	<td align=right>Filename: </td>
	<td>
	  <input type=file name=upload_file size=30>
[im_gif help "Use the &quot;Browse...&quot; button to locate your file, then click &quot;Open&quot;."]
	</td>
      </tr>
      <tr>
	<td></td>
	<td>
	  <input type=submit value=\"Submit and Upload\">
	</td>
      </tr>
    </table>
</form>\n"
	doc_return  200 text/html [im_return_template]
	return
    }

    "up-folder" {

	# --------------------- Up-Folder --------------------- 

	set bread_crum_list [split $bread_crum_path "/"]
	set bread_crum_list_upfolder [lrange $bread_crum_list 0 [expr [llength $bread_crum_list] -2]]
	set bread_crum_path_upfolder [join $bread_crum_list_upfolder "/"]
	ns_set put $bind_vars bread_crum_path $bread_crum_path_upfolder

	ad_returnredirect "$url_base?[export_url_bind_vars $bind_vars]"
    }
    "del" {

	# --------------------- Delete --------------------- 

	set page_title "Delete Files?"
	set context_bar [ad_context_bar $page_title]
	set ctr 0

	set files_html ""
	foreach id [array names file_id] {
	    incr ctr
	    append files_html "<tr $bgcolor([expr $ctr % 2])>
<td>
  <input type=checkbox name=file_id.$id checked>
  <input type=hidden name=id_path.$id value=\"$id_path($id)\">
</td><td>$id_path($id)</td><td></td></tr>\n"
	}

	set dirs_html ""
	foreach id [array names dir_id] {
	    set rel_path $id_path($id)
	    set abs_path "$base_path/$rel_path"
	    set err_msg ""
            set checked "checked"
	    if {![im_filestorage_is_directory_empty $abs_path]} {
		set err_msg "<font color=red>Directory is not empty</font>\n"
                set checked ""
 	    }
	    incr ctr
	    append dirs_html "<tr $bgcolor([expr $ctr % 2])>
<td>
  <input type=checkbox name=dir_id.$id $checked>
  <input type=hidden name=id_path.$id value=\"$id_path($id)\">
</td><td>$id_path($id)</td><td>$err_msg</td></tr>\n"
	}

	set page_body "
<H1>Delete Files</H1>
Are you sure you really want to delete the following files?
<form action=delete method=POST>
[export_form_vars object_id bread_crum_path folder_type return_url]
<input type=submit value='Delete'><p>
<table border=0 cellpadding=1 cellspacing=1>\n"

	if {"" != $dirs_html} {
	    append page_body "<tr class=rowtitle>
	    <td colspan=3 class=rowtitle align=center>Directories</td></tr>$dirs_html"
	}

	if {"" != $files_html} {
	    append page_body "<tr class=rowtitle>
	    <td colspan=3 class=rowtitle align=center>Files</td></tr>$files_html\n"
	}
	append page_body "</table>\n</form>\n"


        if {"" == $dirs_html && "" == $files_html} {
            # Both are empty - show empty help string
            set page_body "
<h1>Nothing Selected</h1>
Please back up and select some files and directories to delete<br>
by marking the checkbox at the left hand side.
"
        }


	doc_return  200 text/html [im_return_template]
	return
    }

    default {

	# --------------------- Default --------------------- 

	ad_returnredirect $return_url
    }
}



set ctr 0
foreach var [ad_ns_set_keys $bind_vars] {
    set value [ns_set get $bind_vars $var]
    if {$ctr > 0} { append vars "&" }
    append vars "$var=$value\n"
    incr ctr
}

append vars "url_base=$url_base\n"

db_release_unused_handles

ad_return_complaint 1 "<pre>$vars</pre>"
return

set page_title "Upload into '$my_folder'"
doc_return  200 text/html [im_return_template]












