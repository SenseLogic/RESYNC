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
    along with Foobar.  If not, see <http://www.gnu.org/licenses/>.
*/

// == LOCAL

// -- IMPORTS

import core.stdc.stdlib : exit;
import core.time : msecs, Duration;
import std.conv : to;
import std.datetime : SysTime;
import std.digest.md : MD5;
import std.file : copy, dirEntries, exists, getAttributes, getTimes, mkdir, mkdirRecurse, readText, remove, rename, rmdir, setAttributes, setTimes, write, FileException, SpanMode;
import std.path : baseName, dirName, globMatch;
import std.stdio : readln, writeln, File;
import std.string : endsWith, indexOf, replace, startsWith, toLower, toUpper;

// == GLOBAL

// -- TYPES

alias HASH
    = ubyte[ 16 ];

// ~~

enum FILE_TYPE
{
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
        ItHasMinimumSampleHash,
        ItHasMediumSampleHash,
        ItHasMaximumSampleHash;
    HASH
        MinimumSampleHash,
        MediumSampleHash,
        MaximumSampleHash;
    string
        TargetFilePath,
        TargetRelativeFilePath;

    // ~~

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

    HASH GetMinimumSampleHash(
        )
    {
        if ( !ItHasMinimumSampleHash )
        {
            if ( VerboseOptionIsEnabled )
            {
                writeln( "Reading minimum sample : ", Path );
            }

            MinimumSampleHash = GetSampleHash( MinimumSampleByteCount );

            ItHasMinimumSampleHash = true;
        }

        return MinimumSampleHash;
    }

    // ~~

    HASH GetMediumSampleHash(
        )
    {
        if ( !ItHasMediumSampleHash )
        {
            if ( VerboseOptionIsEnabled )
            {
                writeln( "Reading medium sample : ", Path );
            }

            MediumSampleHash = GetSampleHash( MediumSampleByteCount );

            ItHasMediumSampleHash = true;
        }

        return MediumSampleHash;
    }

    // ~~

    HASH GetMaximumSampleHash(
        )
    {
        if ( !ItHasMaximumSampleHash )
        {
            if ( VerboseOptionIsEnabled )
            {
                writeln( "Reading maximum sample : ", Path );
            }

            MaximumSampleHash = GetSampleHash( MaximumSampleByteCount );

            ItHasMaximumSampleHash = true;
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
        Path.MoveFile( TargetFilePath );
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
}

// ~~

class SUB_FOLDER
{
    string
        Path,
        RelativePath;
    bool
        ItIsEmpty,
        ItIsEmptied;
}

// ~~

class FOLDER
{
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

    // ~~

    string GetRelativePath(
        string path
        )
    {
        return path[ Path.length .. $ ];
    }

    // ~~

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

        sub_folder = new SUB_FOLDER;
        sub_folder.Path = folder_path;
        sub_folder.RelativePath = relative_folder_path;
        sub_folder.ItIsEmpty = true;

        SubFolderArray ~= sub_folder;
        SubFolderMap[ relative_folder_path ] = sub_folder;

        if ( IsIncludedPath( relative_folder_path, IncludedFolderPathArray, ExcludedFolderPathArray ) )
        {
            try
            {
                foreach ( folder_entry; dirEntries( folder_path, SpanMode.shallow ) )
                {
                    sub_folder.ItIsEmpty = false;

                    if ( folder_entry.isFile()
                         && !folder_entry.isSymlink() )
                    {
                        file_name = folder_entry.baseName();
                        relative_file_path = GetRelativePath( folder_entry );

                        if ( IsIncludedPath( relative_file_path, IncludedFilePathArray, ExcludedFilePathArray )
                             && IsIncludedPath( file_name, IncludedFileNameArray, ExcludedFileNameArray ) )
                        {
                            file = new FILE;
                            file.Name = file_name;
                            file.Path = folder_entry;
                            file.RelativePath = relative_file_path;
                            file.RelativeFolderPath = GetFolderPath( file.RelativePath );
                            file.ModificationTime = folder_entry.timeLastModified;
                            file.ByteCount = folder_entry.size();

                            FileArray ~= file;
                            FileMap[ file.RelativePath ] = file;
                        }
                    }
                }

                foreach ( folder_entry; dirEntries( folder_path, SpanMode.shallow ) )
                {
                    if ( folder_entry.isDir()
                         && !folder_entry.isSymlink() )
                    {
                        Read( folder_entry ~ '/' );
                    }
                }
            }
            catch ( FileException file_exception )
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

        FileArray = [];
        FileMap = null;
        SubFolderArray = [];
        SubFolderMap = null;

        Read( Path );
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
}

// -- VARIABLES

bool
    AddedOptionIsEnabled,
    AdjustedOptionIsEnabled,
    ConfirmOptionIsEnabled,
    ChangedOptionIsEnabled,
    CreateOptionIsEnabled,
    EmptiedOptionIsEnabled,
    MovedOptionIsEnabled,
    PreviewOptionIsEnabled,
    PrintOptionIsEnabled,
    RemovedOptionIsEnabled,
    UpdatedOptionIsEnabled,
    VerboseOptionIsEnabled;
long
    MinimumSampleByteCount,
    MediumSampleByteCount,
    MaximumSampleByteCount;
string
    SourceFolderPath,
    TargetFolderPath;
string[]
    IncludedFolderPathArray,
    ExcludedFolderPathArray,
    IncludedFilePathArray,
    ExcludedFilePathArray,
    IncludedFileNameArray,
    ExcludedFileNameArray;
Duration
    NegativeAdjustedTimeOffset,
    PositiveAdjustedTimeOffset,
    NegativeAllowedTimeOffset,
    PositiveAllowedTimeOffset;
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
        if ( argument.endsWith( 'k' ) )
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

    if ( folder_path == "./"
         && !file_path.startsWith( '.' ) )
    {
        folder_path = "";
    }

    return folder_path;
}

// ~~

bool IsIncludedPath(
    string path,
    string[] included_path_array,
    string[] excluded_path_array
    )
{
    bool
        path_is_included;

    path_is_included = true;

    if ( included_path_array.length > 0
         || excluded_path_array.length > 0 )
    {
        if ( included_path_array.length > 0 )
        {
            path_is_included = false;

            foreach ( included_path; included_path_array )
            {
                if ( path.globMatch( included_path ) )
                {
                    path_is_included = true;
                }
            }
        }

        if ( excluded_path_array.length > 0
             && path_is_included )
        {
            foreach ( excluded_path; excluded_path_array )
            {
                if ( path.globMatch( excluded_path ) )
                {
                    path_is_included = false;

                    break;
                }
            }
        }
    }

    return path_is_included;
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

        foreach ( folder_entry; dirEntries( folder_path, SpanMode.shallow ) )
        {
            it_is_empty_folder = false;

            break;
        }
    }
    catch ( FileException file_exception )
    {
        Abort( "Can't read folder : " ~ folder_path );
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
        catch ( FileException file_exception )
        {
            Abort( "Can't add folder : " ~ folder_path );
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
        catch ( FileException file_exception )
        {
            Abort( "Can't create folder : " ~ folder_path );
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
        catch ( FileException file_exception )
        {
            Abort( "Can't remove file : " ~ file_path );
        }
    }
}

// ~~

void MoveFile(
    string source_file_path,
    string target_file_path
    )
{
    string
        target_folder_path;
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

            source_file_path.getTimes( access_time, modification_time );
            source_file_path.rename( target_file_path );
            target_file_path.setTimes( access_time, modification_time );
        }
        catch ( FileException file_exception )
        {
            Abort( "Can't move file : " ~ source_file_path ~ " => " ~ target_file_path );
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
        catch ( FileException file_exception )
        {
            Abort( "Can't adjust file : " ~ source_file_path ~ " => " ~ target_file_path );
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

            if ( target_file_path.exists() )
            {
                target_file_path.setAttributes( 511 );
            }

            source_file_path.copy( target_file_path );

            target_file_path.setAttributes( attributes );
            target_file_path.setTimes( access_time, modification_time );
        }
        catch ( FileException file_exception )
        {
            Abort( "Can't copy file : " ~ source_file_path ~ " => " ~ target_file_path );
        }
    }
}

// ~~

void FindChangedFiles(
    )
{
    FILE *
        source_file;
    Duration
        modification_time_offset;

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

                modification_time_offset = source_file.ModificationTime - target_file.ModificationTime;

                if ( modification_time_offset >= NegativeAllowedTimeOffset
                     && modification_time_offset <= PositiveAllowedTimeOffset
                     && source_file.ByteCount == target_file.ByteCount
                     && ( MinimumSampleByteCount == 0
                          || source_file.HasIdenticalContent( target_file ) ) )
                {
                    source_file.Type = FILE_TYPE.Identical;
                    target_file.Type = FILE_TYPE.Identical;
                    
                    if ( AdjustedOptionIsEnabled
                         && ( modification_time_offset <= NegativeAdjustedTimeOffset
                              || modification_time_offset >= PositiveAdjustedTimeOffset ) )
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
    if ( VerboseOptionIsEnabled )
    {
        writeln( "Finding moved files" );
    }

    foreach ( target_file; TargetFolder.FileArray )
    {
        if ( target_file.Type == FILE_TYPE.None )
        {
            foreach ( source_file; SourceFolder.FileArray )
            {
                if ( source_file.Type == FILE_TYPE.None
                     && source_file.Name == target_file.Name
                     && source_file.ByteCount == target_file.ByteCount
                     && source_file.HasIdenticalContent( target_file ) )
                {
                    target_file.TargetFilePath = SourceFolder.Path ~ source_file.RelativePath;
                    target_file.TargetRelativeFilePath = source_file.RelativePath;

                    source_file.Type = FILE_TYPE.Moved;
                    target_file.Type = FILE_TYPE.Moved;

                    MovedFileArray ~= target_file;
                }
            }
        }
    }

    foreach ( target_file; TargetFolder.FileArray )
    {
        if ( target_file.Type == FILE_TYPE.None )
        {
            foreach ( source_file; SourceFolder.FileArray )
            {
                if ( source_file.Type == FILE_TYPE.None
                     && source_file.ByteCount == target_file.ByteCount
                     && source_file.HasIdenticalContent( target_file ) )
                {
                    target_file.TargetFilePath = SourceFolder.Path ~ source_file.RelativePath;
                    target_file.TargetRelativeFilePath = source_file.RelativePath;

                    source_file.Type = FILE_TYPE.Moved;
                    target_file.Type = FILE_TYPE.Moved;

                    MovedFileArray ~= target_file;
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
            TargetFolder.SubFolderMap[ target_file.RelativeFolderPath ].ItIsEmptied = true;

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
        writeln( "Moved file : ", moved_file.RelativePath, " => ", moved_file.TargetRelativeFilePath );
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
        if ( target_sub_folder.ItIsEmpty
             || target_sub_folder.ItIsEmptied )
        {
            relative_folder_path = target_sub_folder.RelativePath;

            if ( relative_folder_path != "" )
            {
                source_sub_folder = relative_folder_path in SourceFolder.SubFolderMap;

                if ( source_sub_folder is null )
                {
                    writeln( "Removing folder : " ~ relative_folder_path );
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
        if ( source_sub_folder.ItIsEmpty )
        {
            relative_folder_path = source_sub_folder.RelativePath;

            target_sub_folder = relative_folder_path in TargetFolder.SubFolderMap;

            if ( target_sub_folder is null )
            {
                writeln( "Adding folder : " ~ relative_folder_path );
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
        if ( target_sub_folder.ItIsEmpty
             || target_sub_folder.ItIsEmptied )
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
                            TargetFolder.SubFolderMap[ relative_folder_path ].ItIsEmptied = true;
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
        if ( source_sub_folder.ItIsEmpty )
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
    SourceFolder = new FOLDER;
    TargetFolder = new FOLDER;

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
        Abort( "Invalid folder : " ~ TargetFolder.Path );
    }

    AdjustedFileArray = [];
    UpdatedFileArray = [];
    ChangedFileArray = [];
    MovedFileArray = [];
    RemovedFileArray = [];
    AddedFileArray = [];

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

    if ( PrintOptionIsEnabled )
    {
        PrintChanges();
    }

    if ( !ConfirmOptionIsEnabled
         || AskConfirmation() )
    {
        FixTargetFolder();
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

    AdjustedOptionIsEnabled = false;
    NegativeAdjustedTimeOffset = msecs( 1 );
    PositiveAdjustedTimeOffset = msecs( 1 );
    UpdatedOptionIsEnabled = false;
    ChangedOptionIsEnabled = false;
    MovedOptionIsEnabled = false;
    RemovedOptionIsEnabled = false;
    AddedOptionIsEnabled = false;
    EmptiedOptionIsEnabled = false;
    IncludedFolderPathArray = [];
    ExcludedFolderPathArray = [];
    IncludedFilePathArray = [];
    ExcludedFilePathArray = [];
    IncludedFileNameArray = [];
    ExcludedFileNameArray = [];
    VerboseOptionIsEnabled = false;
    PrintOptionIsEnabled = false;
    ConfirmOptionIsEnabled = false;
    CreateOptionIsEnabled = false;
    PreviewOptionIsEnabled = false;
    MinimumSampleByteCount = 0;
    MediumSampleByteCount = "1M".GetByteCount();
    MaximumSampleByteCount = "all".GetByteCount();
    NegativeAllowedTimeOffset = msecs( -2 );
    PositiveAllowedTimeOffset = msecs( 2 );

    while ( argument_array.length >= 1
            && argument_array[ 0 ].startsWith( "--" ) )
    {
        option = argument_array[ 0 ];

        argument_array = argument_array[ 1 .. $ ];

        if ( option == "--adjusted"
                  && argument_array.length >= 1 )
        {
            AdjustedOptionIsEnabled = true;
            
            millisecond_count = argument_array[ 0 ].to!long();

            NegativeAdjustedTimeOffset = msecs( -millisecond_count );
            PositiveAdjustedTimeOffset = msecs( millisecond_count );

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
        else if ( option == "--include"
                  && argument_array.length >= 1 )
        {
            if ( argument_array[ 0 ].endsWith( '/' ) )
            {
                IncludedFolderPathArray ~= argument_array[ 0 ] ~ '*';
            }
            else if ( argument_array[ 0 ].indexOf( '/' ) >= 0 )
            {
                IncludedFilePathArray ~= argument_array[ 0 ];
            }
            else
            {
                IncludedFileNameArray ~= argument_array[ 0 ];
            }

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--exclude"
                  && argument_array.length >= 1 )
        {
            if ( argument_array[ 0 ].endsWith( '/' ) )
            {
                ExcludedFolderPathArray ~= argument_array[ 0 ] ~ '*';
            }
            else if ( argument_array[ 0 ].indexOf( '/' ) >= 0 )
            {
                ExcludedFilePathArray ~= argument_array[ 0 ];
            }
            else
            {
                ExcludedFileNameArray ~= argument_array[ 0 ];
            }

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--sample"
                  && argument_array.length >= 3 )
        {
            MinimumSampleByteCount = argument_array[ 0 ].GetByteCount();
            MediumSampleByteCount = argument_array[ 0 ].GetByteCount();
            MaximumSampleByteCount = argument_array[ 0 ].GetByteCount();

            argument_array = argument_array[ 3 .. $ ];
        }
        else if ( option == "--allowed"
                  && argument_array.length >= 1 )
        {
            millisecond_count = argument_array[ 0 ].to!long();

            NegativeAllowedTimeOffset = msecs( -millisecond_count );
            PositiveAllowedTimeOffset = msecs( millisecond_count );

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--verbose" )
        {
            VerboseOptionIsEnabled = true;
        }
        else if ( option == "--print" )
        {
            PrintOptionIsEnabled = true;
        }
        else if ( option == "--confirm" )
        {
            ConfirmOptionIsEnabled = true;
        }
        else if ( option == "--create" )
        {
            CreateOptionIsEnabled = true;
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
         && argument_array[ 0 ].endsWith( '/' )
         && argument_array[ 1 ].endsWith( '/' ) )
    {
        SourceFolderPath = argument_array[ 0 ];
        TargetFolderPath = argument_array[ 1 ];

        SynchronizeFolders();
    }
    else
    {
        writeln( "Usage :" );
        writeln( "    resync [options] SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "Options :" );
        writeln( "    --adjusted 1" );
        writeln( "    --updated" );
        writeln( "    --changed" );
        writeln( "    --moved" );
        writeln( "    --removed" );
        writeln( "    --added" );
        writeln( "    --emptied" );
        writeln( "    --include FOLDER_FILTER/file_filter" );
        writeln( "    --exclude FOLDER_FILTER/file_filter" );
        writeln( "    --include FOLDER_FILTER/" );
        writeln( "    --exclude FOLDER_FILTER/" );
        writeln( "    --include file_filter" );
        writeln( "    --exclude file_filter" );
        writeln( "    --sample 0 1M all" );
        writeln( "    --allowed 2" );
        writeln( "    --verbose" );
        writeln( "    --print" );
        writeln( "    --confirm" );
        writeln( "    --create" );
        writeln( "    --preview" );
        writeln( "Examples :" );
        writeln( "    resync --updated --changed --removed --added --emptied --print --confirm --create SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --updated --changed --removed --added --emptied --compare sample --sample 128K 1M 1M --verbose --print --confirm --preview SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --updated --changed --removed --added --emptied --exclude \".git/\" --exclude \"*/.git/\" --exclude \"*.tmp\" --print --confirm SOURCE_FOLDER/ TARGET_FOLDER/" );

        Abort( "Invalid arguments : " ~ argument_array.to!string() );
    }
}
