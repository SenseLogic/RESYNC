/*
    This file is part of the Resync distribution.

    https://github.com/senselogic/RESYNC

    Copyright (C) 2017 Eric Pelzer (ecstatic.coder@gmail.com)

    Resync is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, version 3.

    Resync is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Resync.  If not, see <http://www.gnu.org/licenses/>.
*/

// -- IMPORTS

import core.stdc.stdlib : exit;
import core.time : msecs, Duration;
import std.conv : to;
import std.datetime : Clock, SysTime, UTC;
import std.digest.md : MD5;
import std.file : copy, dirEntries, exists, getAttributes, getSize, getTimes, mkdir, mkdirRecurse, readText, read, readText, remove, rename, rmdir, setAttributes, setTimes, write, PreserveAttributes, SpanMode;
import std.path : globMatch;
import std.stdio : readln, writeln, File;
import std.string : endsWith, indexOf, join, lastIndexOf, replace, startsWith, toLower, toUpper;

// -- TYPES

alias HASH = ubyte[ 16 ];

// ~~

enum FILE_TYPE
{
    // -- CONSTANTS

    None,
    Identical,
    Updated,
    Changed,
    Moved,
    Removed,
    Added
}

// ~~

class FILE
{
    // -- ATTRIBUTES

    FILE_TYPE
        Type;
    string
        Name,
        Path,
        RelativePath,
        RelativeFolderPath;
    long
        ByteCount;
    uint
        AttributeMask;
    SysTime
        ModificationTime,
        AccessTime;
    bool
        HasMinimumSampleHash,
        HasMediumSampleHash,
        HasMaximumSampleHash;
    HASH
        MinimumSampleHash,
        MediumSampleHash,
        MaximumSampleHash;
    string
        SourceFilePath,
        SourceRelativeFilePath,
        TargetFilePath,
        TargetRelativeFilePath;

    // -- INQUIRIES

    HASH GetSampleHash(
        long byte_count
        )
    {
        long
            step_byte_count;
        File
            file;
        HASH
            hash;
        MD5
            md5;

        if ( byte_count > ByteCount )
        {
            byte_count = ByteCount;
        }

        if ( byte_count > 0 )
        {
            step_byte_count = 4096 * 1024;

            if ( step_byte_count > byte_count )
            {
                step_byte_count = byte_count;
            }

            file = File( Path );

            foreach ( buffer; file.byChunk( step_byte_count ) )
            {
                md5.put( buffer );

                byte_count -= step_byte_count;

                if ( byte_count <= 0 )
                {
                    break;
                }

                if ( step_byte_count > byte_count )
                {
                    step_byte_count = byte_count;
                }
            }

            hash = md5.finish();
        }

        return hash;
    }

    // ~~

    void Dump(
        )
    {
        writeln(
            Path,
            ", ",
            RelativePath,
            ", ",
            ByteCount,
            ", ",
            AttributeMask,
            ", ",
            ModificationTime,
            ", ",
            AccessTime,
            ", ",
            Type,
            " ",
            TargetFilePath,
            " ",
            TargetRelativeFilePath
            );
    }

    // -- OPERATIONS

    HASH GetMinimumSampleHash(
        )
    {
        if ( !HasMinimumSampleHash )
        {
            if ( VerboseOptionIsEnabled )
            {
                writeln( "Reading minimum sample : ", Path );
            }

            MinimumSampleHash = GetSampleHash( MinimumSampleByteCount );

            HasMinimumSampleHash = true;
        }

        return MinimumSampleHash;
    }

    // ~~

    HASH GetMediumSampleHash(
        )
    {
        if ( !HasMediumSampleHash )
        {
            if ( VerboseOptionIsEnabled )
            {
                writeln( "Reading medium sample : ", Path );
            }

            MediumSampleHash = GetSampleHash( MediumSampleByteCount );

            HasMediumSampleHash = true;
        }

        return MediumSampleHash;
    }

    // ~~

    HASH GetMaximumSampleHash(
        )
    {
        if ( !HasMaximumSampleHash )
        {
            if ( VerboseOptionIsEnabled )
            {
                writeln( "Reading maximum sample : ", Path );
            }

            MaximumSampleHash = GetSampleHash( MaximumSampleByteCount );

            HasMaximumSampleHash = true;
        }

        return MaximumSampleHash;
    }

    // ~~

    bool HasIdenticalContent(
        FILE other_file
        )
    {
        return
            ByteCount == other_file.ByteCount
            && ( MinimumSampleByteCount == 0
                 || GetMinimumSampleHash() == other_file.GetMinimumSampleHash() )
            && ( MediumSampleByteCount == 0
                 || ByteCount <= MinimumSampleByteCount
                 || MediumSampleByteCount <= MinimumSampleByteCount
                 || GetMediumSampleHash() == other_file.GetMediumSampleHash() )
            && ( MaximumSampleByteCount == 0
                 || ByteCount <= MediumSampleByteCount
                 || MaximumSampleByteCount <= MediumSampleByteCount
                 || GetMaximumSampleHash() == other_file.GetMaximumSampleHash() );
    }

    // ~~

    void Remove(
        )
    {
        Path.RemoveFile();
    }

    // ~~

    void Move(
        )
    {
        Path.MoveFile( TargetFilePath, SourceFilePath );
    }

    // ~~

    void Adjust(
        )
    {
        Path.AdjustFile( TargetFilePath );
    }

    // ~~

    void Copy(
        )
    {
        Path.CopyFile( TargetFilePath );
    }
}

// ~~

class SUB_FOLDER
{
    // -- ATTRIBUTES

    string
        Path,
        RelativePath;
    bool
        IsEmpty,
        IsEmptied;
}

// ~~

class FOLDER
{
    // -- ATTRIBUTES

    string
        Path;
    FILE[]
        FileArray;
    FILE[ string ]
        FileMap;
    SUB_FOLDER[]
        SubFolderArray;
    SUB_FOLDER[ string ]
        SubFolderMap;

    // -- INQUIRIES

    string GetRelativePath(
        string path
        )
    {
        return path[ Path.length .. $ ];
    }

    // ~~

    FILE[] GetUnmatchedFileArray(
        )
    {
        FILE[]
            unmatched_file_array;

        foreach ( file; FileArray )
        {
            if ( file.Type == FILE_TYPE.None )
            {
                unmatched_file_array ~= file;
            }
        }

        return unmatched_file_array;
    }

    // ~~

    void Dump(
        )
    {
        foreach ( file; FileArray )
        {
            file.Dump();
        }
    }

    // -- OPERATIONS

    void Add(
        )
    {
        writeln( "Adding folder : ", Path );

        Path.AddFolder();
    }

    // ~~

    void Read(
        string folder_path
        )
    {
        string
            file_name,
            file_path,
            relative_file_path,
            relative_folder_path;
        FILE
            file;
        SUB_FOLDER
            sub_folder;

        relative_folder_path = GetRelativePath( folder_path );

        if ( IsIncludedFolder( "/" ~ relative_folder_path ) )
        {
            sub_folder = new SUB_FOLDER();
            sub_folder.Path = folder_path;
            sub_folder.RelativePath = relative_folder_path;
            sub_folder.IsEmpty = true;

            SubFolderArray ~= sub_folder;
            SubFolderMap[ relative_folder_path ] = sub_folder;

            try
            {
                foreach ( folder_entry; dirEntries( folder_path, SpanMode.shallow ) )
                {
                    sub_folder.IsEmpty = false;

                    if ( folder_entry.isFile
                         && !folder_entry.isSymlink )
                    {
                        file_path = folder_entry.name;
                        file_name = file_path.GetFileName();
                        relative_file_path = GetRelativePath( file_path );

                        if ( IsIncludedFile( "/" ~ relative_folder_path, "/" ~ relative_file_path, file_name )
                             && IsSelectedFile( "/" ~ relative_folder_path, "/" ~ relative_file_path, file_name ) )
                        {
                            file = new FILE();
                            file.Name = file_name;
                            file.Path = file_path;
                            file.RelativePath = relative_file_path;
                            file.RelativeFolderPath = GetFolderPath( file.RelativePath );
                            file.ByteCount = folder_entry.size;
                            file.AttributeMask = folder_entry.attributes;
                            file.ModificationTime = folder_entry.timeLastModified;
                            file.AccessTime = folder_entry.timeLastAccessed;

                            FileArray ~= file;
                            FileMap[ file.RelativePath ] = file;
                        }
                    }
                }

                foreach ( folder_entry; dirEntries( folder_path, SpanMode.shallow ) )
                {
                    if ( folder_entry.isDir
                         && !folder_entry.isSymlink )
                    {
                        Read( folder_entry.name ~ '/' );
                    }
                }
            }
            catch ( Exception exception )
            {
                Abort( "Can't read folder : " ~ folder_path );
            }
        }
    }

    // ~~

    void Read(
        )
    {
        writeln( "Reading folder : ", Path );

        FileArray = null;
        FileMap = null;
        SubFolderArray = null;
        SubFolderMap = null;

        Read( Path );
    }
}

// -- VARIABLES

bool
    AbortOptionIsEnabled,
    AddedOptionIsEnabled,
    AdjustedOptionIsEnabled,
    ConfirmOptionIsEnabled,
    ChangedOptionIsEnabled,
    CreateOptionIsEnabled,
    EmptiedOptionIsEnabled,
    MovedOptionIsEnabled,
    PreviewOptionIsEnabled,
    StoreOptionIsEnabled,
    RemovedOptionIsEnabled,
    UpdatedOptionIsEnabled,
    VerboseOptionIsEnabled;
bool[]
    FileFilterIsInclusiveArray,
    FolderFilterIsInclusiveArray;
long
    MinimumSampleByteCount,
    MediumSampleByteCount,
    MaximumSampleByteCount;
string
    ChangeListFileText,
    ChangeFolderPath,
    SourceFolderPath,
    TargetFolderPath;
string[]
    ErrorMessageArray,
    FileFilterArray,
    FolderFilterArray,
    SelectedFileFilterArray;
Duration
    NegativeAdjustedOffsetDuration,
    NegativeAllowedOffsetDuration,
    PositiveAdjustedOffsetDuration,
    PositiveAllowedOffsetDuration;
FILE[]
    AddedFileArray,
    AdjustedFileArray,
    ChangedFileArray,
    MovedFileArray,
    RemovedFileArray,
    UpdatedFileArray;
FOLDER
    SourceFolder,
    TargetFolder;

// -- FUNCTIONS

void PrintError(
    string message
    )
{
    writeln( "*** ERROR : ", message );

    ErrorMessageArray ~= message;
}

// ~~

void Abort(
    string message
    )
{
    PrintError( message );

    exit( -1 );
}

// ~~

void Abort(
    string message,
    Exception exception,
    bool it_must_exit = false
    )
{
    PrintError( message );
    PrintError( exception.msg );

    if ( it_must_exit
         || AbortOptionIsEnabled )
    {
        exit( -1 );
    }
}

// ~~

SysTime GetCurrentTime(
    )
{
    return Clock.currTime();
}

// ~~

ulong GetTime(
    SysTime system_time
    )
{
    return system_time.stdTime();
}

// ~~

SysTime GetTime(
    ulong time
    )
{
    return SysTime( time, UTC() );
}

// ~~

string GetTimeStamp(
    ulong time
    )
{
    string
        time_stamp;

    time_stamp = ( time.GetTime().toISOString().replace( "T", "" ).replace( "Z", "" ).replace( ".", "" ) ~ "0000000" )[ 0 .. 21 ];

    return
        time_stamp[ 0 .. 8 ]
        ~ "_"
        ~ time_stamp[ 8 .. 14 ]
        ~ "_"
        ~ time_stamp[ 14 .. $ ];
}

// ~~

string GetCurrentTimeStamp(
    )
{
    return GetTimeStamp( GetCurrentTime().GetTime() );
}

// ~~

long GetByteCount(
    string argument
    )
{
    long
        byte_count,
        unit_byte_count;

    argument = argument.toLower();

    if ( argument == "all" )
    {
        byte_count = long.max;
    }
    else
    {
        if ( argument.endsWith( 'b' ) )
        {
            unit_byte_count = 1;

            argument = argument[ 0 .. $ - 1 ];
        }
        else if ( argument.endsWith( 'k' ) )
        {
            unit_byte_count = 1024;

            argument = argument[ 0 .. $ - 1 ];
        }
        else if ( argument.endsWith( 'm' ) )
        {
            unit_byte_count = 1024 * 1024;

            argument = argument[ 0 .. $ - 1 ];
        }
        else if ( argument.endsWith( 'g' ) )
        {
            unit_byte_count = 1024 * 1024 * 1024;

            argument = argument[ 0 .. $ - 1 ];
        }
        else
        {
            unit_byte_count = 1;
        }

        byte_count = argument.to!long() * unit_byte_count;
    }

    return byte_count;
}

// ~~

bool IsRootPath(
    string folder_path
    )
{
    return
        folder_path.startsWith( '/' )
        || folder_path.endsWith( '\\' );
}

// ~~

bool IsFolderPath(
    string folder_path
    )
{
    return
        folder_path.endsWith( '/' )
        || folder_path.endsWith( '\\' );
}

// ~~

bool IsFilter(
    string folder_path
    )
{
    return
        folder_path.indexOf( '*' ) >= 0
        || folder_path.indexOf( '?' ) >= 0;
}

// ~~

string GetLogicalPath(
    string path
    )
{
    return path.replace( '\\', '/' );
}

// ~~

string GetFolderPath(
    string file_path
    )
{
    long
        slash_character_index;

    slash_character_index = file_path.lastIndexOf( '/' );

    if ( slash_character_index >= 0 )
    {
        return file_path[ 0 .. slash_character_index + 1 ];
    }
    else
    {
        return "";
    }
}

// ~~

string GetSuperFolderPath(
    string folder_path
    )
{
    if ( folder_path.endsWith( '/' ) )
    {
        return GetFolderPath( folder_path[ 0 .. $ - 1 ] );
    }
    else
    {
        return GetFolderPath( folder_path );
    }
}

// ~~

string GetFileName(
    string file_path
    )
{
    long
        slash_character_index;

    slash_character_index = file_path.lastIndexOf( '/' );

    if ( slash_character_index >= 0 )
    {
        return file_path[ slash_character_index + 1 .. $ ];
    }
    else
    {
        return file_path;
    }
}

// ~~

bool IsIncludedFolder(
    string folder_path
    )
{
    bool
        folder_filter_is_inclusive,
        folder_is_included;

    folder_is_included = true;

    if ( FolderFilterArray.length > 0 )
    {
        foreach ( folder_filter_index, folder_filter; FolderFilterArray )
        {
            folder_filter_is_inclusive = FolderFilterIsInclusiveArray[ folder_filter_index ];

            if ( folder_filter_is_inclusive )
            {
                if ( folder_path.startsWith( folder_filter )
                     || folder_filter.startsWith( folder_path ) )
                {
                    folder_is_included = true;
                }
            }
            else
            {
                if ( !folder_filter.startsWith( '/' )
                     && !folder_filter.startsWith( '*' ) )
                {
                    folder_filter = "*/" ~ folder_filter;
                }

                if ( folder_path.globMatch( folder_filter ~ '*' ) )
                {
                    folder_is_included = false;
                }
            }
        }
    }

    return folder_is_included;
}

// ~~

bool IsIncludedFile(
    string folder_path,
    string file_path,
    string file_name
    )
{
    bool
        file_filter_is_inclusive,
        file_is_included;
    string
        file_name_filter,
        folder_path_filter;

    file_is_included = true;

    if ( FileFilterArray.length > 0 )
    {
        foreach ( file_filter_index, file_filter; FileFilterArray )
        {
            file_filter_is_inclusive = FileFilterIsInclusiveArray[ file_filter_index ];

            if ( !file_filter.startsWith( '/' )
                 && !file_filter.startsWith( '*' ) )
            {
                file_filter = "*/" ~ file_filter;
            }

            if ( file_filter.endsWith( '/' ) )
            {
                if ( folder_path.globMatch( file_filter ~ '*' ) )
                {
                    file_is_included = file_filter_is_inclusive;
                }
            }
            else if ( file_filter.indexOf( '/' ) >= 0 )
            {
                folder_path_filter = file_filter.GetFolderPath();
                file_name_filter = file_filter.GetFileName();

                if ( folder_path.globMatch( folder_path_filter )
                     && file_name.globMatch( file_name_filter ) )
                {
                    file_is_included = file_filter_is_inclusive;
                }
            }
            else
            {
                if ( file_name.globMatch( file_filter ) )
                {
                    file_is_included = file_filter_is_inclusive;
                }
            }
        }
    }

    return file_is_included;
}

// ~~

bool IsSelectedFile(
    string folder_path,
    string file_path,
    string file_name
    )
{
    bool
        file_is_selected;
    long
        selected_file_filter_index;
    string
        file_name_filter,
        folder_path_filter,
        selected_file_filter;

    file_is_selected = ( SelectedFileFilterArray.length == 0 );

    for ( selected_file_filter_index = 0;
          selected_file_filter_index < SelectedFileFilterArray.length
          && !file_is_selected;
          ++selected_file_filter_index )
    {
        selected_file_filter = SelectedFileFilterArray[ selected_file_filter_index ];

        if ( !selected_file_filter.startsWith( '/' )
             && !selected_file_filter.startsWith( '*' ) )
        {
            selected_file_filter = "*/" ~ selected_file_filter;
        }

        if ( selected_file_filter.endsWith( '/' ) )
        {
            if ( folder_path.globMatch( selected_file_filter ~ '*' ) )
            {
                file_is_selected = true;
            }
        }
        else if ( selected_file_filter.indexOf( '/' ) >= 0 )
        {
            folder_path_filter = selected_file_filter.GetFolderPath();
            file_name_filter = selected_file_filter.GetFileName();

            if ( folder_path.globMatch( folder_path_filter )
                 && file_name.globMatch( file_name_filter ) )
            {
                file_is_selected = true;
            }
        }
        else
        {
            if ( file_name.globMatch( selected_file_filter ) )
            {
                file_is_selected = true;
            }
        }
    }

    return file_is_selected;
}

// ~~

bool IsEmptyFolder(
    string folder_path
    )
{
    bool
        it_is_empty_folder;

    try
    {
        it_is_empty_folder = true;

        foreach ( file_path; dirEntries( folder_path, SpanMode.shallow ) )
        {
            it_is_empty_folder = false;

            break;
        }
    }
    catch ( Exception exception )
    {
        Abort( "Can't read folder : " ~ folder_path, exception, true );
    }

    return it_is_empty_folder;
}

// ~~

void AddFolder(
    string folder_path
    )
{
    if ( !PreviewOptionIsEnabled )
    {
        try
        {
            if ( folder_path != ""
                 && folder_path != "/"
                 && !folder_path.exists() )
            {
                folder_path.mkdirRecurse();
            }
        }
        catch ( Exception exception )
        {
            Abort( "Can't add folder : " ~ folder_path, exception, true );
        }
    }
}

// ~~

void RemoveFolder(
    string folder_path
    )
{
    if ( !PreviewOptionIsEnabled )
    {
        try
        {
            folder_path.rmdir();
        }
        catch ( Exception exception )
        {
            Abort( "Can't remove folder : " ~ folder_path, exception, true );
        }
    }
}

// ~~

void RemoveFile(
    string file_path
    )
{
    if ( !PreviewOptionIsEnabled )
    {
        try
        {
            file_path.remove();
        }
        catch ( Exception exception )
        {
            Abort( "Can't remove file : " ~ file_path, exception );
        }
    }
}

// ~~

void StoreFile(
    string source_file_path,
    string target_file_path
    )
{
    string
        target_folder_path;
    uint
        attribute_mask;
    SysTime
        access_time,
        modification_time;

    if ( !PreviewOptionIsEnabled )
    {
        try
        {
            target_folder_path = GetFolderPath( target_file_path );

            if ( !target_folder_path.exists() )
            {
                writeln( "Adding folder : ", target_folder_path[ ChangeFolderPath.length .. $ ] );

                target_folder_path.AddFolder();
            }

            attribute_mask = source_file_path.getAttributes();
            source_file_path.getTimes( access_time, modification_time );

            source_file_path.rename( target_file_path );

            target_file_path.setAttributes( attribute_mask );
            target_file_path.setTimes( access_time, modification_time );
        }
        catch ( Exception exception )
        {
            Abort( "Can't store file : " ~ source_file_path ~ " => " ~ target_file_path, exception );
        }
    }
}

// ~~

void MoveFile(
    string source_file_path,
    string target_file_path,
    string reference_file_path = ""
    )
{
    string
        target_folder_path;
    uint
        attribute_mask;
    SysTime
        access_time,
        modification_time;

    if ( !PreviewOptionIsEnabled )
    {
        try
        {
            target_folder_path = GetFolderPath( target_file_path );

            if ( !target_folder_path.exists() )
            {
                writeln( "Adding folder : ", TargetFolder.GetRelativePath( target_folder_path ) );

                target_folder_path.AddFolder();
            }

            if ( reference_file_path == "" )
            {
                reference_file_path = source_file_path;
            }

            attribute_mask = reference_file_path.getAttributes();
            reference_file_path.getTimes( access_time, modification_time );

            source_file_path.rename( target_file_path );

            target_file_path.setAttributes( attribute_mask );
            target_file_path.setTimes( access_time, modification_time );
        }
        catch ( Exception exception )
        {
            Abort( "Can't move file : " ~ source_file_path ~ " => " ~ target_file_path, exception );
        }
    }
}

// ~~

void AdjustFile(
    string source_file_path,
    string target_file_path
    )
{
    uint
        attribute_mask;
    SysTime
        access_time,
        modification_time;

    if ( !PreviewOptionIsEnabled )
    {
        try
        {
            attribute_mask = source_file_path.getAttributes();
            source_file_path.getTimes( access_time, modification_time );

            target_file_path.setAttributes( attribute_mask );
            target_file_path.setTimes( access_time, modification_time );
        }
        catch ( Exception exception )
        {
            Abort( "Can't adjust file : " ~ source_file_path ~ " => " ~ target_file_path, exception );
        }
    }
}

// ~~

void CopyFile(
    string source_file_path,
    string target_file_path
    )
{
    string
        target_folder_path;
    uint
        attribute_mask;
    SysTime
        access_time,
        modification_time;

    if ( !PreviewOptionIsEnabled )
    {
        try
        {
            target_folder_path = GetFolderPath( target_file_path );

            if ( !target_folder_path.exists() )
            {
                writeln( "Adding folder : ", TargetFolder.GetRelativePath( target_folder_path ) );

                target_folder_path.AddFolder();
            }

            attribute_mask = source_file_path.getAttributes();
            source_file_path.getTimes( access_time, modification_time );

            version ( Windows )
            {
                if ( target_file_path.exists() )
                {
                    target_file_path.setAttributes( attribute_mask & ~1 );
                }

                source_file_path.copy( target_file_path, PreserveAttributes.no );

                target_file_path.setAttributes( attribute_mask & ~1 );
                target_file_path.setTimes( access_time, modification_time );
                target_file_path.setAttributes( attribute_mask );
            }
            else
            {
                if ( target_file_path.exists() )
                {
                    target_file_path.setAttributes( 511 );
                }

                source_file_path.copy( target_file_path, PreserveAttributes.no );

                target_file_path.setAttributes( attribute_mask );
                target_file_path.setTimes( access_time, modification_time );
            }
        }
        catch ( Exception exception )
        {
            Abort( "Can't copy file : " ~ source_file_path ~ " => " ~ target_file_path, exception );
        }
    }
}

// ~~

ubyte[] ReadByteArray(
    string file_path
    )
{
    ubyte[]
        file_byte_array;

    writeln( "Reading file : ", file_path );

    try
    {
        file_byte_array = cast( ubyte[] )file_path.read();
    }
    catch ( Exception exception )
    {
        Abort( "Can't read file : " ~ file_path, exception );
    }

    return file_byte_array;
}

// ~~

void WriteByteArray(
    string file_path,
    ubyte[] file_byte_array
    )
{
    writeln( "Writing file : ", file_path );

    try
    {
        file_path.write( file_byte_array );
    }
    catch ( Exception exception )
    {
        Abort( "Can't write file : " ~ file_path, exception );
    }
}

// ~~

string ReadText(
    string file_path
    )
{
    string
        file_text;

    writeln( "Reading file : ", file_path );

    try
    {
        file_text = file_path.readText();
    }
    catch ( Exception exception )
    {
        Abort( "Can't read file : " ~ file_path, exception );
    }

    return file_text;
}

// ~~

void WriteText(
    string file_path,
    string file_text
    )
{
    writeln( "Writing file : ", file_path );

    try
    {
        file_path.write( file_text );
    }
    catch ( Exception exception )
    {
        Abort( "Can't write file : " ~ file_path, exception );
    }
}

// ~~

void FindChangedFiles(
    )
{
    Duration
        modification_time_offset_duration;
    FILE *
        source_file;

    if ( VerboseOptionIsEnabled )
    {
        writeln( "Finding changed files" );
    }

    foreach ( target_file; TargetFolder.FileArray )
    {
        if ( target_file.Type == FILE_TYPE.None )
        {
            source_file = target_file.RelativePath in SourceFolder.FileMap;

            if ( source_file !is null )
            {
                source_file.SourceFilePath = source_file.Path;
                source_file.SourceRelativeFilePath = source_file.RelativePath;
                source_file.TargetFilePath = target_file.Path;
                source_file.TargetRelativeFilePath = target_file.RelativePath;

                modification_time_offset_duration = source_file.ModificationTime - target_file.ModificationTime;

                if ( source_file.ByteCount == target_file.ByteCount
                     && modification_time_offset_duration >= NegativeAllowedOffsetDuration
                     && modification_time_offset_duration <= PositiveAllowedOffsetDuration
                     && ( MinimumSampleByteCount == 0
                          || source_file.HasIdenticalContent( target_file ) ) )
                {
                    source_file.Type = FILE_TYPE.Identical;
                    target_file.Type = FILE_TYPE.Identical;

                    if ( AdjustedOptionIsEnabled
                         && ( modification_time_offset_duration <= NegativeAdjustedOffsetDuration
                              || modification_time_offset_duration >= PositiveAdjustedOffsetDuration ) )
                    {
                        AdjustedFileArray ~= *source_file;
                    }
                }
                else
                {
                    if ( source_file.ModificationTime > target_file.ModificationTime )
                    {
                        source_file.Type = FILE_TYPE.Updated;
                        target_file.Type = FILE_TYPE.Updated;

                        UpdatedFileArray ~= *source_file;
                    }
                    else
                    {
                        source_file.Type = FILE_TYPE.Changed;
                        target_file.Type = FILE_TYPE.Changed;

                        ChangedFileArray ~= *source_file;
                    }
                }
            }
        }
    }
}

// ~~

void FindMovedFiles(
    )
{
    bool
        files_have_same_content,
        files_have_same_modification_time,
        files_have_same_name;
    Duration
        modification_time_offset_duration;
    FILE[]
        source_file_array,
        target_file_array;

    if ( VerboseOptionIsEnabled )
    {
        writeln( "Finding moved files" );
    }

    source_file_array = SourceFolder.GetUnmatchedFileArray();
    target_file_array = TargetFolder.GetUnmatchedFileArray();

    foreach ( pass_index; 0 .. 3 )
    {
        foreach ( target_file; target_file_array )
        {
            if ( target_file.Type == FILE_TYPE.None )
            {
                foreach ( source_file; source_file_array )
                {
                    if ( target_file.Type == FILE_TYPE.None
                         && source_file.Type == FILE_TYPE.None
                         && source_file.ByteCount == target_file.ByteCount )
                    {
                        if ( pass_index < 2 )
                        {
                            files_have_same_name = ( source_file.Name == target_file.Name );
                        }
                        else
                        {
                            files_have_same_name = true;
                        }

                        if ( pass_index == 0
                             && MinimumSampleByteCount == 0 )
                        {
                            modification_time_offset_duration = source_file.ModificationTime - target_file.ModificationTime;

                            files_have_same_modification_time
                                = ( modification_time_offset_duration >= NegativeAllowedOffsetDuration
                                    && modification_time_offset_duration <= PositiveAllowedOffsetDuration );

                            files_have_same_content
                                = ( files_have_same_name
                                    && files_have_same_modification_time );
                        }
                        else
                        {
                            files_have_same_modification_time = true;
                            files_have_same_content = source_file.HasIdenticalContent( target_file );
                        }

                        if ( files_have_same_name
                             && files_have_same_modification_time
                             && files_have_same_content )
                        {
                            target_file.SourceFilePath = source_file.Path;
                            target_file.SourceRelativeFilePath = source_file.RelativePath;
                            target_file.TargetFilePath = TargetFolder.Path ~ source_file.RelativePath;
                            target_file.TargetRelativeFilePath = source_file.RelativePath;

                            source_file.Type = FILE_TYPE.Moved;
                            target_file.Type = FILE_TYPE.Moved;

                            MovedFileArray ~= target_file;
                        }
                    }
                }
            }
        }
    }
}

// ~~

void FindRemovedFiles(
    )
{
    if ( VerboseOptionIsEnabled )
    {
        writeln( "Finding removed files" );
    }

    foreach ( target_file; TargetFolder.FileArray )
    {
        if ( target_file.Type == FILE_TYPE.None )
        {
            TargetFolder.SubFolderMap[ target_file.RelativeFolderPath ].IsEmptied = true;

            target_file.Type = FILE_TYPE.Removed;
            target_file.SourceFilePath = "";
            target_file.SourceRelativeFilePath = "";
            target_file.TargetFilePath = TargetFolder.Path ~ target_file.RelativePath;
            target_file.TargetRelativeFilePath = target_file.RelativePath;

            RemovedFileArray ~= target_file;
        }
    }
}

// ~~

void FindAddedFiles(
    )
{
    if ( VerboseOptionIsEnabled )
    {
        writeln( "Finding added files" );
    }

    foreach ( source_file; SourceFolder.FileArray )
    {
        if ( source_file.Type == FILE_TYPE.None )
        {
            source_file.SourceFilePath = source_file.Path;
            source_file.SourceRelativeFilePath = source_file.RelativePath;
            source_file.TargetFilePath = TargetFolder.Path ~ source_file.RelativePath;
            source_file.TargetRelativeFilePath = source_file.RelativePath;

            source_file.Type = FILE_TYPE.Added;

            AddedFileArray ~= source_file;
        }
    }
}

// ~~

void PrintMovedFiles(
    )
{
    foreach ( moved_file; MovedFileArray )
    {
        writeln( "Moved file : ", moved_file.RelativePath );
        writeln( "             ", moved_file.TargetRelativeFilePath );
    }
}

// ~~

void PrintRemovedFiles(
    )
{
    foreach ( removed_file; RemovedFileArray )
    {
        writeln( "Removed file : ", removed_file.RelativePath );
    }
}

// ~~

void PrintAdjustedFiles(
    )
{
    foreach ( adjusted_file; AdjustedFileArray )
    {
        writeln( "Adjusted file : ", adjusted_file.RelativePath );
    }
}

// ~~

void PrintUpdatedFiles(
    )
{
    foreach ( updated_file; UpdatedFileArray )
    {
        writeln( "Updated file : ", updated_file.RelativePath );
    }
}

// ~~

void PrintChangedFiles(
    )
{
    foreach ( changed_file; ChangedFileArray )
    {
        writeln( "Changed file : ", changed_file.RelativePath );
    }
}

// ~~

void PrintAddedFiles(
    )
{
    foreach ( added_file; AddedFileArray )
    {
        writeln( "Added file : ", added_file.RelativePath );
    }
}

// ~~

void PrintRemovedFolders(
    )
{
    string
        relative_folder_path;
    SUB_FOLDER *
        source_sub_folder;

    foreach_reverse ( target_sub_folder; TargetFolder.SubFolderArray )
    {
        if ( target_sub_folder.IsEmpty
             || target_sub_folder.IsEmptied )
        {
            relative_folder_path = target_sub_folder.RelativePath;

            if ( relative_folder_path != "" )
            {
                source_sub_folder = relative_folder_path in SourceFolder.SubFolderMap;

                if ( source_sub_folder is null )
                {
                    writeln( "Removed folder : ", relative_folder_path );
                }
            }
        }
    }
}

// ~~

void PrintAddedFolders(
    )
{
    string
        relative_folder_path;
    SUB_FOLDER *
        target_sub_folder;

    foreach ( source_sub_folder; SourceFolder.SubFolderArray )
    {
        if ( source_sub_folder.IsEmpty )
        {
            relative_folder_path = source_sub_folder.RelativePath;

            target_sub_folder = relative_folder_path in TargetFolder.SubFolderMap;

            if ( target_sub_folder is null )
            {
                writeln( "Added folder : ", relative_folder_path );
            }
        }
    }
}

// ~~

void PrintChanges(
    )
{
    if ( MovedOptionIsEnabled )
    {
        PrintMovedFiles();
    }

    if ( RemovedOptionIsEnabled )
    {
        PrintRemovedFiles();
    }

    if ( AdjustedOptionIsEnabled )
    {
        PrintAdjustedFiles();
    }

    if ( UpdatedOptionIsEnabled )
    {
        PrintUpdatedFiles();
    }

    if ( ChangedOptionIsEnabled )
    {
        PrintChangedFiles();
    }

    if ( AddedOptionIsEnabled )
    {
        PrintAddedFiles();
    }

    if ( EmptiedOptionIsEnabled )
    {
        PrintRemovedFolders();
        PrintAddedFolders();
    }
}

// ~~

bool AskConfirmation(
    )
{
    writeln( "Do you want to apply these changes ? (y/n)" );

    return readln().toLower().startsWith( "y" );
}

// ~~

void StoreChange(
    string command,
    string source_file_path,
    string source_relative_file_path,
    string target_file_path,
    string target_relative_file_path
    )
{
    uint
        source_attribute_mask,
        target_attribute_mask;
    ulong
        source_byte_count,
        target_byte_count;
    SysTime
        source_access_time,
        source_modification_time,
        target_access_time,
        target_modification_time;

    if ( source_file_path != "" )
    {
        source_attribute_mask = source_file_path.getAttributes();
        source_file_path.getTimes( source_access_time, source_modification_time );

        if ( !source_file_path.endsWith( '/' ) )
        {
            source_byte_count = source_file_path.getSize();
        }
    }

    if ( target_file_path != "" )
    {
        target_attribute_mask = target_file_path.getAttributes();
        target_file_path.getTimes( target_access_time, target_modification_time );

        if ( !target_file_path.endsWith( '/' ) )
        {
            target_byte_count = target_file_path.getSize();
        }
    }

    ChangeListFileText ~= command;

    if ( source_file_path != "" )
    {
        ChangeListFileText
            ~= "\t"
               ~ source_relative_file_path
               ~ "\t"
               ~ source_byte_count.to!string()
               ~ "\t"
               ~ source_attribute_mask.to!string()
               ~ "\t"
               ~ source_modification_time.GetTime().to!string()
               ~ "\t"
               ~ source_access_time.GetTime().to!string();
    }

    if ( target_file_path != "" )
    {
        ChangeListFileText
            ~= "\t"
               ~ target_relative_file_path
               ~ "\t"
               ~ target_byte_count.to!string()
               ~ "\t"
               ~ target_attribute_mask.to!string()
               ~ "\t"
               ~ target_modification_time.GetTime().to!string()
               ~ "\t"
               ~ target_access_time.GetTime().to!string();
    }

    ChangeListFileText ~= "\n";
}

// ~~

void StoreMovedFile(
    FILE moved_file
    )
{
    StoreChange(
        "&",
        moved_file.SourceFilePath,
        moved_file.SourceRelativeFilePath,
        moved_file.TargetFilePath,
        moved_file.TargetRelativeFilePath
        );
}

// ~~

void StoreRemovedFile(
    FILE removed_file
    )
{
    StoreChange(
        "-",
        "",
        "",
        removed_file.TargetFilePath,
        removed_file.TargetRelativeFilePath
        );

    writeln( "Storing file : ", removed_file.TargetRelativeFilePath );

    removed_file.TargetFilePath.StoreFile(
        ChangeFolderPath ~ "REMOVED/" ~ removed_file.TargetRelativeFilePath
        );
}

// ~~

void StoreAdjustedFile(
    FILE adjusted_file
    )
{
    StoreChange(
        "~",
        adjusted_file.SourceFilePath,
        adjusted_file.SourceRelativeFilePath,
        adjusted_file.TargetFilePath,
        adjusted_file.TargetRelativeFilePath
        );
}

// ~~

void StoreUpdatedFile(
    FILE updated_file
    )
{
    StoreChange(
        "%",
        updated_file.SourceFilePath,
        updated_file.SourceRelativeFilePath,
        updated_file.TargetFilePath,
        updated_file.TargetRelativeFilePath
        );

    writeln( "Storing file : ", updated_file.TargetRelativeFilePath );

    updated_file.TargetFilePath.StoreFile(
        ChangeFolderPath ~ "UPDATED/" ~ updated_file.TargetRelativeFilePath
        );
}

// ~~

void StoreChangedFile(
    FILE changed_file
    )
{
    StoreChange(
        "#",
        changed_file.SourceFilePath,
        changed_file.SourceRelativeFilePath,
        changed_file.TargetFilePath,
        changed_file.TargetRelativeFilePath
        );

    writeln( "Storing file : ", changed_file.TargetRelativeFilePath );

    changed_file.TargetFilePath.StoreFile(
        ChangeFolderPath ~ "CHANGED/" ~ changed_file.TargetRelativeFilePath
        );
}

// ~~

void StoreAddedFile(
    FILE added_file
    )
{
    StoreChange(
        "+",
        added_file.SourceFilePath,
        added_file.SourceRelativeFilePath,
        "",
        ""
        );
}

// ~~

void StoreRemovedFolder(
    string removed_folder_path,
    string removed_relative_folder_path
    )
{
    StoreChange(
        "\\",
        "",
        "",
        removed_folder_path,
        removed_relative_folder_path
        );
}

// ~~

void StoreAddedFolder(
    string added_folder_path,
    string added_relative_folder_path
    )
{
    StoreChange(
        "/",
        added_folder_path,
        added_relative_folder_path,
        "",
        ""
        );
}

// ~~

void StoreChangeListFile(
    )
{
    WriteText( ChangeFolderPath ~ "change_list.txt", ChangeListFileText );
}

// ~~

void StoreFileListFile(
    )
{
    string
        file_list_file_text;

    foreach ( file; SourceFolder.FileArray )
    {
        file_list_file_text
            ~= file.RelativePath
               ~ "\t"
               ~ file.ByteCount.to!string()
               ~ "\t"
               ~ file.AttributeMask.to!string()
               ~ "\t"
               ~ file.ModificationTime.GetTime().to!string()
               ~ "\t"
               ~ file.AccessTime.GetTime().to!string()
               ~ "\n";
    }

    WriteText( ChangeFolderPath ~ "file_list.txt", file_list_file_text );
}

// ~~

void StoreFolderListFile(
    )
{
    uint
        attribute_mask;
    string
        folder_list_file_text;
    SysTime
        access_time,
        modification_time;

    foreach ( sub_folder; SourceFolder.SubFolderArray )
    {
        attribute_mask = sub_folder.Path.getAttributes();
        sub_folder.Path.getTimes( access_time, modification_time );

        folder_list_file_text
            ~= sub_folder.RelativePath
               ~ "\t"
               ~ attribute_mask.to!string()
               ~ "\t"
               ~ modification_time.GetTime().to!string()
               ~ "\t"
               ~ access_time.GetTime().to!string()
               ~ "\t"
               ~ ( sub_folder.IsEmpty ? "1" : "0" )
               ~ "\n";
    }

    WriteText( ChangeFolderPath ~ "folder_list.txt", folder_list_file_text );
}

// ~~

void MoveFiles(
    )
{
    foreach ( moved_file; MovedFileArray )
    {
        if ( StoreOptionIsEnabled )
        {
            StoreMovedFile( moved_file );
        }

        writeln( "Moving file : ", moved_file.RelativePath, " => ", moved_file.TargetRelativeFilePath );

        moved_file.Move();
    }
}

// ~~

void RemoveFiles(
    )
{
    foreach ( removed_file; RemovedFileArray )
    {
        if ( StoreOptionIsEnabled )
        {
            StoreRemovedFile( removed_file );
        }

        writeln( "Removing file : ", removed_file.RelativePath );

        if ( !StoreOptionIsEnabled )
        {
            removed_file.Remove();
        }
    }
}

// ~~

void AdjustFiles(
    )
{
    foreach ( adjusted_file; AdjustedFileArray )
    {
        if ( StoreOptionIsEnabled )
        {
            StoreAdjustedFile( adjusted_file );
        }

        writeln( "Adjusting file : ", adjusted_file.RelativePath );

        adjusted_file.Adjust();
    }
}

// ~~

void UpdateFiles(
    )
{
    foreach ( updated_file; UpdatedFileArray )
    {
        if ( StoreOptionIsEnabled )
        {
            StoreUpdatedFile( updated_file );
        }

        writeln( "Updating file : ", updated_file.RelativePath );

        updated_file.Copy();
    }
}

// ~~

void ChangeFiles(
    )
{
    foreach ( changed_file; ChangedFileArray )
    {
        if ( StoreOptionIsEnabled )
        {
            StoreChangedFile( changed_file );
        }

        writeln( "Changing file : ", changed_file.RelativePath );

        changed_file.Copy();
    }
}

// ~~

void AddFiles(
    )
{
    foreach ( added_file; AddedFileArray )
    {
        if ( StoreOptionIsEnabled )
        {
            StoreAddedFile( added_file );
        }

        writeln( "Adding file : ", added_file.RelativePath );

        added_file.Copy();
    }
}

// ~~

void RemoveFolders(
    )
{
    string
        relative_folder_path,
        target_folder_path;
    SUB_FOLDER *
        source_sub_folder;

    foreach_reverse ( target_sub_folder; TargetFolder.SubFolderArray )
    {
        if ( target_sub_folder.IsEmpty
             || target_sub_folder.IsEmptied )
        {
            relative_folder_path = target_sub_folder.RelativePath;

            while ( relative_folder_path != "" )
            {
                source_sub_folder = relative_folder_path in SourceFolder.SubFolderMap;

                if ( source_sub_folder is null )
                {
                    target_folder_path = TargetFolder.Path ~ relative_folder_path;

                    if ( target_folder_path.exists()
                         && target_folder_path.IsEmptyFolder() )
                    {
                        if ( StoreOptionIsEnabled )
                        {
                            StoreRemovedFolder( target_folder_path, relative_folder_path );
                        }

                        writeln( "Removing folder : ", relative_folder_path );

                        target_folder_path.RemoveFolder();

                        relative_folder_path = GetSuperFolderPath( relative_folder_path );

                        if ( relative_folder_path != "" )
                        {
                            TargetFolder.SubFolderMap[ relative_folder_path ].IsEmptied = true;
                        }
                    }
                    else
                    {
                        break;
                    }
                }
                else
                {
                    break;
                }
            }
        }
    }
}

// ~~

void AddFolders(
    )
{
    string
        relative_folder_path,
        target_folder_path;
    SUB_FOLDER *
        target_sub_folder;

    foreach ( source_sub_folder; SourceFolder.SubFolderArray )
    {
        if ( source_sub_folder.IsEmpty )
        {
            relative_folder_path = source_sub_folder.RelativePath;

            target_sub_folder = relative_folder_path in TargetFolder.SubFolderMap;

            if ( target_sub_folder is null )
            {
                target_folder_path = TargetFolder.Path ~ relative_folder_path;

                if ( !target_folder_path.exists() )
                {
                    if ( StoreOptionIsEnabled )
                    {
                        StoreAddedFolder( target_folder_path, relative_folder_path );
                    }

                    writeln( "Adding folder : ", relative_folder_path );

                    target_folder_path.AddFolder();
                }
            }
        }
    }
}

// ~~

void FixTargetFolder(
    )
{
    if ( MovedOptionIsEnabled )
    {
        MoveFiles();
    }

    if ( RemovedOptionIsEnabled )
    {
        RemoveFiles();
    }

    if ( AdjustedOptionIsEnabled )
    {
        AdjustFiles();
    }

    if ( UpdatedOptionIsEnabled )
    {
        UpdateFiles();
    }

    if ( ChangedOptionIsEnabled )
    {
        ChangeFiles();
    }

    if ( AddedOptionIsEnabled )
    {
        AddFiles();
    }

    if ( EmptiedOptionIsEnabled )
    {
        RemoveFolders();
        AddFolders();
    }

    if ( StoreOptionIsEnabled )
    {
        AddFolder( ChangeFolderPath );

        StoreChangeListFile();
        StoreFileListFile();
        StoreFolderListFile();
    }
}

// ~~

void SynchronizeFolders(
    )
{
    if ( SourceFolderPath != TargetFolderPath )
    {
        SourceFolder = new FOLDER();
        TargetFolder = new FOLDER();

        SourceFolder.Path = SourceFolderPath;
        TargetFolder.Path = TargetFolderPath;

        SourceFolder.Read();

        if ( TargetFolder.Path.exists() )
        {
            TargetFolder.Read();
        }
        else if ( CreateOptionIsEnabled )
        {
            TargetFolder.Add();
        }
        else
        {
            Abort( "Invalid folder target : " ~ TargetFolder.Path );
        }

        AdjustedFileArray = null;
        UpdatedFileArray = null;
        ChangedFileArray = null;
        MovedFileArray = null;
        RemovedFileArray = null;
        AddedFileArray = null;

        FindChangedFiles();

        if ( MovedOptionIsEnabled )
        {
            FindMovedFiles();
        }

        if ( RemovedOptionIsEnabled )
        {
            FindRemovedFiles();
        }

        if ( AddedOptionIsEnabled )
        {
            FindAddedFiles();
        }

        if ( ConfirmOptionIsEnabled )
        {
            PrintChanges();

            if ( AskConfirmation() )
            {
                FixTargetFolder();
            }
        }
        else
        {
            FixTargetFolder();
        }
    }
    else
    {
        Abort( "Invalid target folder : " ~ TargetFolder.Path );
    }

    if ( ErrorMessageArray.length > 0 )
    {
        writeln( "*** ERRORS :\n", ErrorMessageArray.join( '\n' ) );
    }
}

// ~~

void main(
    string[] argument_array
    )
{
    long
        millisecond_count;
    string
        option;

    argument_array = argument_array[ 1 .. $ ];

    ErrorMessageArray = null;
    CreateOptionIsEnabled = false;
    AdjustedOptionIsEnabled = false;
    NegativeAdjustedOffsetDuration = msecs( 1 );
    PositiveAdjustedOffsetDuration = msecs( 1 );
    UpdatedOptionIsEnabled = false;
    ChangedOptionIsEnabled = false;
    MovedOptionIsEnabled = false;
    RemovedOptionIsEnabled = false;
    AddedOptionIsEnabled = false;
    EmptiedOptionIsEnabled = false;
    StoreOptionIsEnabled = false;
    ChangeFolderPath = "";
    FolderFilterArray = null;
    FolderFilterIsInclusiveArray = null;
    FileFilterArray = null;
    FileFilterIsInclusiveArray = null;
    SelectedFileFilterArray = null;
    MinimumSampleByteCount = 0;
    MediumSampleByteCount = "1m".GetByteCount();
    MaximumSampleByteCount = "all".GetByteCount();
    NegativeAllowedOffsetDuration = msecs( -2 );
    PositiveAllowedOffsetDuration = msecs( 2 );
    AbortOptionIsEnabled = false;
    VerboseOptionIsEnabled = false;
    ConfirmOptionIsEnabled = false;
    PreviewOptionIsEnabled = false;

    while ( argument_array.length >= 1
            && argument_array[ 0 ].startsWith( "--" ) )
    {
        option = argument_array[ 0 ];

        argument_array = argument_array[ 1 .. $ ];

        if ( option == "--create" )
        {
            CreateOptionIsEnabled = true;
        }
        else if ( option == "--adjusted"
                  && argument_array.length >= 1 )
        {
            AdjustedOptionIsEnabled = true;

            millisecond_count = argument_array[ 0 ].to!long();

            NegativeAdjustedOffsetDuration = msecs( -millisecond_count );
            PositiveAdjustedOffsetDuration = msecs( millisecond_count );

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--updated" )
        {
            UpdatedOptionIsEnabled = true;
        }
        else if ( option == "--changed" )
        {
            ChangedOptionIsEnabled = true;
        }
        else if ( option == "--moved" )
        {
            MovedOptionIsEnabled = true;
        }
        else if ( option == "--removed" )
        {
            RemovedOptionIsEnabled = true;
        }
        else if ( option == "--added" )
        {
            AddedOptionIsEnabled = true;
        }
        else if ( option == "--emptied" )
        {
            EmptiedOptionIsEnabled = true;
        }
        else if ( option == "--store"
                  && argument_array.length >= 1
                  && argument_array[ 0 ].IsFolderPath() )
        {
            StoreOptionIsEnabled = true;
            ChangeFolderPath = argument_array[ 0 ].GetLogicalPath() ~ GetCurrentTimeStamp() ~ "/";
            ChangeListFileText = "";

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--exclude"
                  && argument_array.length >= 1
                  && argument_array[ 0 ].IsFolderPath() )
        {
            FolderFilterArray ~= argument_array[ 0 ].GetLogicalPath();
            FolderFilterIsInclusiveArray ~= false;

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--include"
                  && argument_array.length >= 1
                  && argument_array[ 0 ].IsRootPath()
                  && argument_array[ 0 ].IsFolderPath()
                  && !argument_array[ 0 ].IsFilter() )
        {
            FolderFilterArray ~= argument_array[ 0 ].GetLogicalPath();
            FolderFilterIsInclusiveArray ~= true;

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( ( option == "--ignore"
                    || option == "--keep" )
                  && argument_array.length >= 1 )
        {
            FileFilterArray ~= argument_array[ 0 ].GetLogicalPath();
            FileFilterIsInclusiveArray ~= ( option == "--keep" );

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--select"
                  && argument_array.length >= 1 )
        {
            SelectedFileFilterArray ~= argument_array[ 0 ].GetLogicalPath();

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--sample"
                  && argument_array.length >= 3 )
        {
            MinimumSampleByteCount = argument_array[ 0 ].GetByteCount();
            MediumSampleByteCount = argument_array[ 1 ].GetByteCount();
            MaximumSampleByteCount = argument_array[ 2 ].GetByteCount();

            argument_array = argument_array[ 3 .. $ ];
        }
        else if ( option == "--allowed"
                  && argument_array.length >= 1 )
        {
            millisecond_count = argument_array[ 0 ].to!long();

            NegativeAllowedOffsetDuration = msecs( -millisecond_count );
            PositiveAllowedOffsetDuration = msecs( millisecond_count );

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--abort" )
        {
            AbortOptionIsEnabled = true;
        }
        else if ( option == "--verbose" )
        {
            VerboseOptionIsEnabled = true;
        }
        else if ( option == "--confirm" )
        {
            ConfirmOptionIsEnabled = true;
        }
        else if ( option == "--preview" )
        {
            PreviewOptionIsEnabled = true;
        }
        else
        {
            Abort( "Invalid option : " ~ option );
        }
    }

    if ( argument_array.length == 2
         && argument_array[ 0 ].GetLogicalPath().endsWith( '/' )
         && argument_array[ 1 ].GetLogicalPath().endsWith( '/' ) )
    {
        SourceFolderPath = argument_array[ 0 ].GetLogicalPath();
        TargetFolderPath = argument_array[ 1 ].GetLogicalPath();

        SynchronizeFolders();
    }
    else
    {
        writeln( "Usage :" );
        writeln( "    resync [options] SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "Options :" );
        writeln( "    --create" );
        writeln( "    --adjusted 1" );
        writeln( "    --updated" );
        writeln( "    --changed" );
        writeln( "    --moved" );
        writeln( "    --removed" );
        writeln( "    --added" );
        writeln( "    --emptied" );
        writeln( "    --store CHANGE_FOLDER/" );
        writeln( "    --exclude FOLDER_FILTER/" );
        writeln( "    --include FOLDER/" );
        writeln( "    --ignore file_filter" );
        writeln( "    --keep file_filter" );
        writeln( "    --sample 0 1m all" );
        writeln( "    --allowed 2" );
        writeln( "    --abort" );
        writeln( "    --verbose" );
        writeln( "    --confirm" );
        writeln( "    --preview" );
        writeln( "Examples :" );
        writeln( "    resync --create --updated --changed --removed --added --emptied --confirm SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --create --updated --changed --removed --added --emptied --store CHANGE_FOLDER/ SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --updated --changed --removed --added --moved --emptied --verbose --confirm SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --updated --changed --removed --added --moved --emptied --sample 128k 1m 1m --verbose --confirm SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --updated --changed --removed --added --emptied --exclude \".git/\" --ignore \"*.tmp\" --confirm SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --updated --changed --removed --added --emptied --select \"/A/\" --select \"/C/\" --confirm SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --updated --removed --added --preview SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --adjusted 1 --allowed 2 --confirm SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --moved --confirm SOURCE_FOLDER/ TARGET_FOLDER/" );

        Abort( "Invalid arguments : " ~ argument_array.to!string() );
    }
}

