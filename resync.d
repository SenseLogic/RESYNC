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
import std.datetime : SysTime;
import std.digest.md : MD5;
import std.file : copy, dirEntries, exists, getAttributes, getTimes, mkdir, mkdirRecurse, readText, remove, rename, rmdir, setAttributes, setTimes, write, PreserveAttributes, SpanMode;
import std.path : baseName, dirName, globMatch;
import std.stdio : readln, writeln, File;
import std.string : endsWith, indexOf, join, replace, startsWith, toLower, toUpper;

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
    SysTime
        ModificationTime;
    long
        ByteCount;
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
            ModificationTime,
            ", ",
            ByteCount,
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
            ( MinimumSampleByteCount == 0
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
                foreach ( file_path; dirEntries( folder_path, SpanMode.shallow ) )
                {
                    sub_folder.IsEmpty = false;

                    if ( file_path.isFile()
                         && !file_path.isSymlink() )
                    {
                        file_name = file_path.baseName();
                        relative_file_path = GetRelativePath( file_path );

                        if ( IsIncludedFile( "/" ~ relative_folder_path, "/" ~ relative_file_path, file_name ) )
                        {
                            file = new FILE();
                            file.Name = file_name;
                            file.Path = file_path;
                            file.RelativePath = relative_file_path;
                            file.RelativeFolderPath = GetFolderPath( file.RelativePath );
                            file.ModificationTime = file_path.timeLastModified;
                            file.ByteCount = file_path.size();

                            FileArray ~= file;
                            FileMap[ file.RelativePath ] = file;
                        }
                    }
                }

                foreach ( file_path; dirEntries( folder_path, SpanMode.shallow ) )
                {
                    if ( file_path.isDir()
                         && !file_path.isSymlink() )
                    {
                        Read( file_path ~ '/' );
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
    SourceFolderPath,
    TargetFolderPath;
string[]
    ErrorMessageArray,
    FileFilterArray,
    FolderFilterArray;
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

string GetLogicalPath(
    string path
    )
{
    return path.replace( "\\", "/" );
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

string GetFolderPath(
    string file_path
    )
{
    string
        folder_path;

    folder_path = file_path.dirName();

    if ( folder_path != "" )
    {
        folder_path ~= '/';
    }

    if ( folder_path == "./" )
    {
        folder_path = "";
    }

    return folder_path;
}

// ~~

bool IsIncludedFolder(
    string folder_path
    )
{
    bool
        folder_filter_is_inclusive,
        folder_is_included;
    long
        folder_filter_index;
    string
        folder_filter;

    folder_is_included = true;

    if ( FolderFilterArray.length > 0 )
    {
        for ( folder_filter_index = 0;
              folder_filter_index < FolderFilterArray.length;
              ++folder_filter_index )
        {
            folder_filter = FolderFilterArray[ folder_filter_index ];
            folder_filter_is_inclusive = FolderFilterIsInclusiveArray[ folder_filter_index ];

            if ( !folder_filter.startsWith( '/' )
                 && !folder_filter.startsWith( '*' ) )
            {
                folder_filter = "*/" ~ folder_filter;
            }

            if ( folder_path.globMatch( folder_filter ~ '*' ) )
            {
                folder_is_included = folder_filter_is_inclusive;
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
    long
        file_filter_index;
    string
        file_filter;

    file_is_included = true;

    if ( FileFilterArray.length > 0 )
    {
        for ( file_filter_index = 0;
              file_filter_index < FileFilterArray.length;
              ++file_filter_index )
        {
            file_filter = FileFilterArray[ file_filter_index ];
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
                if ( file_path.globMatch( file_filter ) )
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

void MoveFile(
    string source_file_path,
    string target_file_path,
    string reference_file_path
    )
{
    string
        target_folder_path;
    uint
        attributes;
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

            attributes = reference_file_path.getAttributes();
            reference_file_path.getTimes( access_time, modification_time );

            source_file_path.rename( target_file_path );

            target_file_path.setAttributes( attributes );
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
        attributes;
    SysTime
        access_time,
        modification_time;

    if ( !PreviewOptionIsEnabled )
    {
        try
        {
            attributes = source_file_path.getAttributes();
            source_file_path.getTimes( access_time, modification_time );

            target_file_path.setAttributes( attributes );
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
        attributes;
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

            attributes = source_file_path.getAttributes();
            source_file_path.getTimes( access_time, modification_time );

            version ( Windows )
            {
                if ( target_file_path.exists() )
                {
                    target_file_path.setAttributes( attributes & ~1 );
                }

                source_file_path.copy( target_file_path, PreserveAttributes.no );

                target_file_path.setAttributes( attributes & ~1 );
                target_file_path.setTimes( access_time, modification_time );
                target_file_path.setAttributes( attributes );
            }
            else
            {
                if ( target_file_path.exists() )
                {
                    target_file_path.setAttributes( 511 );
                }

                source_file_path.copy( target_file_path, PreserveAttributes.no );

                target_file_path.setAttributes( attributes );
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

    if ( VerboseOptionIsEnabled )
    {
        writeln( "Finding moved files" );
    }

    foreach ( pass_index; 0 .. 3 )
    {
        foreach ( target_file; TargetFolder.FileArray )
        {
            if ( target_file.Type == FILE_TYPE.None )
            {
                foreach ( source_file; SourceFolder.FileArray )
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

void MoveFiles(
    )
{
    foreach ( moved_file; MovedFileArray )
    {
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
        writeln( "Removing file : ", removed_file.RelativePath );

        removed_file.Remove();
    }
}

// ~~

void AdjustFiles(
    )
{
    foreach ( adjusted_file; AdjustedFileArray )
    {
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
                        writeln( "Removing folder : ", relative_folder_path );

                        target_folder_path.RemoveFolder();

                        relative_folder_path = GetFolderPath( relative_folder_path );

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
    FolderFilterArray = null;
    FolderFilterIsInclusiveArray = null;
    FileFilterArray = null;
    FileFilterIsInclusiveArray = null;
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
        else if ( ( option == "--exclude"
                    || option == "--include" )
                  && argument_array.length >= 1
                  && argument_array[ 0 ].IsFolderPath() )
        {
            FolderFilterArray ~= argument_array[ 0 ].GetLogicalPath();
            FolderFilterIsInclusiveArray ~= ( option == "--include" );

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
        writeln( "    --exclude FOLDER_FILTER/" );
        writeln( "    --include FOLDER_FILTER/" );
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
        writeln( "    resync --updated --changed --removed --added --moved --emptied --verbose --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --updated --changed --removed --added --moved --emptied --sample 128k 1m 1m --verbose --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --updated --changed --removed --added --emptied --exclude \".git/\" --ignore \"*.tmp\" --confirm SOURCE_FOLDER/ TARGET_FOLDER/" );

        Abort( "Invalid arguments : " ~ argument_array.to!string() );
    }
}
