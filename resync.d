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
import std.file : copy, dirEntries, exists, getAttributes, getTimes, mkdir, mkdirRecurse, readText, remove, rename, setAttributes, setTimes, write, SpanMode;
import std.path : baseName, dirName, globMatch;
import std.stdio : readln, writeln, File;
import std.string : endsWith, indexOf, replace, startsWith, toLower;

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
        Path,
        RelativePath,
        RelativeFolderPath,
        Name;
    SysTime
        ModificationTime;
    long
        ByteCount;
    bool
        ItHasSampleHash,
        ItHasHash;
    HASH
        SampleHash,
        Hash;
    string
        TargetFilePath,
        TargetFileRelativePath;

    // ~~

    HASH GetHash(
        long byte_count
        )
    {
        long
            step_byte_count;
        File
            file;
        MD5
            hash;

        if ( byte_count > ByteCount )
        {
            byte_count = ByteCount;
        }

        step_byte_count = 4096 * 1024;

        if ( step_byte_count > byte_count )
        {
            step_byte_count = byte_count;
        }

        file = File( Path );

        foreach ( buffer; file.byChunk( step_byte_count ) )
        {
            hash.put( buffer );

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

        return hash.finish();
    }

    // ~~

    HASH GetSampleHash(
        )
    {
        if ( !ItHasSampleHash )
        {
            SampleHash = GetHash( SampleByteCount );

            ItHasSampleHash = true;
        }

        return SampleHash;
    }

    // ~~

    HASH GetHash(
        )
    {
        if ( !ItHasHash )
        {
            Hash = GetHash( ByteCount );

            ItHasHash = true;
        }

        return Hash;
    }

    // ~~

    bool HasIdenticalContent(
        FILE other_file
        )
    {
        return
            ByteCount == other_file.ByteCount
            && ( SampleByteCount <= 0
                 || GetSampleHash() == other_file.GetSampleHash() )
            && ( ByteCount <= SampleByteCount
                 || GetHash() == other_file.GetHash() );
    }
    
    // ~~
    
    void Remove(
        )
    {
        if ( !PreviewOptionIsEnabled )
        {
            Path.RemoveFile();
        }
    }
    
    // ~~
    
    void Move(
        )
    {
        if ( !PreviewOptionIsEnabled )
        {
            Path.MoveFile( TargetFilePath );
        }
    }

    // ~~

    void Copy(
        )
    {
        if ( !PreviewOptionIsEnabled )
        {
            Path.CopyFile( TargetFilePath );
        }
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
            TargetFileRelativePath 
            );
    }
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

    // ~~

    string GetRelativePath(
        string path
        )
    {
        return path[ Path.length .. $ ];
    }
    
    // ~~
    
    bool IsIncludedFolder(
        string folder_path
        )
    {
        bool
            folder_is_included;
            
        folder_is_included = true;
        
        if ( IncludedFolderPathArray.length > 0
             || ExcludedFolderPathArray.length > 0 )
        {
            if ( IncludedFolderPathArray.length > 0 )
            {
                folder_is_included = false;
                
                foreach ( included_folder_path; IncludedFolderPathArray )
                {
                    if ( folder_path.startsWith( included_folder_path ) )
                    {
                        folder_is_included = true;
                    }
                }
            }
            
            if ( ExcludedFolderPathArray.length > 0
                 && folder_is_included )
            {
                foreach ( excluded_folder_path; ExcludedFolderPathArray )
                {
                    if ( folder_path.startsWith( excluded_folder_path ) )
                    {
                        folder_is_included = false;

                        break;
                    }
                }
            }
        }

        return folder_is_included;
    }
    
    // ~~
    
    bool IsIncludedFile(
        string file_name
        )
    {
        bool
            file_is_included;
            
        file_is_included = true;
        
        if ( IncludedFileNameFilterArray.length > 0
             || ExcludedFileNameFilterArray.length > 0 )
        {
            if ( IncludedFileNameFilterArray.length > 0 )
            {
                file_is_included = false;
                
                foreach ( included_file_name_filter; IncludedFileNameFilterArray )
                {
                    if ( file_name.globMatch( included_file_name_filter ) )
                    {
                        file_is_included = true;
                    }
                }
            }
            
            if ( ExcludedFileNameFilterArray.length > 0
                 && file_is_included )
            {
                foreach ( excluded_file_name_filter; ExcludedFileNameFilterArray )
                {
                    if ( file_name.globMatch( excluded_file_name_filter ) )
                    {
                        file_is_included = false;

                        break;
                    }
                }
            }
        }

        return file_is_included;
    }

    // ~~

    void Read(
        string folder_path
        )
    {
        string
            file_name;
        FILE
            file;

        if ( IsIncludedFolder( GetRelativePath( folder_path ) ) )
        {
            try
            {
                foreach ( folder_entry; dirEntries( folder_path, SpanMode.shallow ) )
                {
                    if ( folder_entry.isFile()
                         && !folder_entry.isSymlink() )
                    {
                        file_name = folder_entry.baseName();
                        
                        if ( IsIncludedFile( file_name ) )
                        {
                            file = new FILE;
                            file.Path = folder_entry;
                            file.RelativePath = GetRelativePath( file.Path );
                            file.RelativeFolderPath = GetFolderPath( file.RelativePath );
                            file.Name = file_name;
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
            catch ( Error error )
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
    ConfirmOptionIsEnabled,
    ChangedOptionIsEnabled,
    MovedOptionIsEnabled,
    PreviewOptionIsEnabled,
    PrintOptionIsEnabled,
    RemovedOptionIsEnabled,
    UpdatedOptionIsEnabled;
long
    SampleByteCount;
string
    SourceFolderPath,
    TargetFolderPath;
string[]
    IncludedFolderPathArray,
    ExcludedFolderPathArray,
    IncludedFileNameFilterArray,
    ExcludedFileNameFilterArray;
Duration
    MinimumModificationTimeOffset,
    MaximumModificationTimeOffset;
FILE[]
    AddedFileArray,
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
    
    return folder_path;
}

// ~~

void CreateFolder(
    string folder_path
    )
{
    string
        super_folder_path;

    try
    {
        if ( folder_path != ""
             && folder_path != "/"
             && !folder_path.exists() )
        {
            writeln( "Creating folder : ", folder_path );

            folder_path.mkdirRecurse();
        }
    }
    catch ( Error error )
    {
        Abort( "Can't create folder : " ~ folder_path );
    }
}

// ~~

void RemoveFile(
    string file_path
    )
{
    try
    {
        file_path.remove();
    }
    catch ( Error error )
    {
        Abort( "Can't remove file : " ~ file_path );
    }
}

// ~~

void MoveFile(
    string source_file_path,
    string target_file_path
    )
{
    try
    {
        SysTime
            access_time,
            modification_time;

        GetFolderPath( target_file_path ).CreateFolder();

        source_file_path.getTimes( access_time, modification_time );
        source_file_path.rename( target_file_path );
        target_file_path.setTimes( access_time, modification_time );
    }
    catch ( Error error )
    {
        Abort( "Can't move file : " ~ source_file_path ~ " => " ~ target_file_path );
    }
}

// ~~

void CopyFile(
    string source_file_path,
    string target_file_path
    )
{
    try
    {
        uint
            attributes;
        SysTime
            access_time,
            modification_time;

        GetFolderPath( target_file_path ).CreateFolder();

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
    catch ( Error error )
    {
        Abort( "Can't copy file : " ~ source_file_path ~ " => " ~ target_file_path );
    }

}

// ~~

void FindUpdatedFiles(
    )
{
    FILE *
        source_file;
    Duration
        modification_time_offset;

    foreach ( target_file; TargetFolder.FileArray )
    {
        if ( target_file.Type == FILE_TYPE.None )
        {
            source_file = target_file.RelativePath in SourceFolder.FileMap;

            if ( source_file !is null )
            {
                source_file.TargetFilePath = target_file.Path;
                source_file.TargetFileRelativePath = target_file.RelativePath;

                modification_time_offset = source_file.ModificationTime - target_file.ModificationTime;

                if ( modification_time_offset >= MinimumModificationTimeOffset
                     && modification_time_offset <= MaximumModificationTimeOffset
                     && source_file.ByteCount == target_file.ByteCount )
                {
                    source_file.Type = FILE_TYPE.Identical;
                    target_file.Type = FILE_TYPE.Identical;
                }
                else
                {
                    if ( source_file.ModificationTime < target_file.ModificationTime
                         || ChangedOptionIsEnabled )
                    {
                        source_file.Type = FILE_TYPE.Changed;
                        target_file.Type = FILE_TYPE.Changed;

                        ChangedFileArray ~= *source_file;
                    }
                    else
                    {
                        source_file.Type = FILE_TYPE.Updated;
                        target_file.Type = FILE_TYPE.Updated;

                        UpdatedFileArray ~= *source_file;
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
    foreach ( target_file; TargetFolder.FileArray )
    {
        if ( target_file.Type == FILE_TYPE.None )
        {
            foreach ( source_file; SourceFolder.FileArray )
            {
                if ( source_file.Type == FILE_TYPE.None
                     && source_file.Name == target_file.Name
                     && source_file.HasIdenticalContent( target_file ) )
                {
                    target_file.TargetFilePath = SourceFolderPath ~ source_file.RelativePath;
                    target_file.TargetFileRelativePath = source_file.RelativePath;
                    
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
                     && source_file.HasIdenticalContent( target_file ) )
                {
                    target_file.TargetFilePath = SourceFolderPath ~ source_file.RelativePath;
                    target_file.TargetFileRelativePath = source_file.RelativePath;
                    
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
    foreach ( target_file; TargetFolder.FileArray )
    {
        if ( target_file.Type == FILE_TYPE.None )
        {
            target_file.Type = FILE_TYPE.Removed;

            RemovedFileArray ~= target_file;
        }
    }
}

// ~~

void FindAddedFiles(
    )
{
    foreach ( source_file; SourceFolder.FileArray )
    {
        if ( source_file.Type == FILE_TYPE.None )
        {
            source_file.TargetFilePath = TargetFolderPath ~ source_file.RelativePath;
            source_file.TargetFileRelativePath = source_file.RelativePath;
            
            source_file.Type = FILE_TYPE.Added;

            AddedFileArray ~= source_file;
        }
    }
}

// ~~

void PrintChanges(
    )
{
    if ( MovedOptionIsEnabled )
    {
        foreach ( moved_file; MovedFileArray )
        {
            writeln( "Moved file : ", moved_file.RelativePath, " => ", moved_file.TargetFileRelativePath );
        }
    }

    if ( RemovedOptionIsEnabled )
    {
        foreach ( removed_file; RemovedFileArray )
        {
            writeln( "Removed file : ", removed_file.RelativePath );
        }
    }

    if ( UpdatedOptionIsEnabled )
    {
        foreach ( updated_file; UpdatedFileArray )
        {
            writeln( "Updated file : ", updated_file.RelativePath );
        }
    }

    if ( ChangedOptionIsEnabled )
    {
        foreach ( changed_file; ChangedFileArray )
        {
            writeln( "Changed file : ", changed_file.RelativePath );
        }
    }

    if ( AddedOptionIsEnabled )
    {
        foreach ( added_file; AddedFileArray )
        {
            writeln( "Added file : ", added_file.RelativePath );
        }
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

void FixTargetFolder(
    )
{
    if ( MovedOptionIsEnabled )
    {
        foreach ( moved_file; MovedFileArray )
        {
            writeln( "Moving file : ", moved_file.RelativePath, " => ", moved_file.TargetFileRelativePath );

            moved_file.Move();
        }
    }

    if ( RemovedOptionIsEnabled )
    {
        foreach ( removed_file; RemovedFileArray )
        {
            writeln( "Removing file : ", removed_file.RelativePath );

            removed_file.Remove();
        }
    }

    if ( UpdatedOptionIsEnabled )
    {
        foreach ( updated_file; UpdatedFileArray )
        {
            writeln( "Updating file : ", updated_file.RelativePath );

            updated_file.Copy();
        }
    }

    if ( ChangedOptionIsEnabled )
    {
        foreach ( changed_file; ChangedFileArray )
        {
            writeln( "Copying file : ", changed_file.RelativePath );

            changed_file.Copy();
        }
    }

    if ( AddedOptionIsEnabled )
    {
        foreach ( added_file; AddedFileArray )
        {
            writeln( "Adding file : ", added_file.RelativePath );

            added_file.Copy();
        }
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
    TargetFolder.Read();

    UpdatedFileArray = [];
    ChangedFileArray = [];
    MovedFileArray = [];
    RemovedFileArray = [];
    AddedFileArray = [];

    FindUpdatedFiles();

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

    UpdatedOptionIsEnabled = false;
    ChangedOptionIsEnabled = false;
    MovedOptionIsEnabled = false;
    RemovedOptionIsEnabled = false;
    AddedOptionIsEnabled = false;
    IncludedFolderPathArray = [];
    ExcludedFolderPathArray = [];
    IncludedFileNameFilterArray = [];
    ExcludedFileNameFilterArray = [];
    PrintOptionIsEnabled = false;
    ConfirmOptionIsEnabled = false;
    PreviewOptionIsEnabled = false;
    SampleByteCount = 128 * 1024;
    MinimumModificationTimeOffset = msecs( -1 );
    MaximumModificationTimeOffset = msecs( 1 );

    while ( argument_array.length >= 1
            && argument_array[ 0 ].startsWith( "--" ) )
    {
        option = argument_array[ 0 ];

        argument_array = argument_array[ 1 .. $ ];
        
        if ( option == "--updated" )
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
        else if ( option == "--include"
             && argument_array.length >= 1 )
        {
            if ( argument_array[ 0 ].endsWith( '/' ) )
            {
                IncludedFolderPathArray ~= argument_array[ 0 ];
            }
            else
            {
                IncludedFileNameFilterArray ~= argument_array[ 0 ];
            }

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--include"
                  && argument_array.length >= 1 )
        {
            IncludedFolderPathArray ~= argument_array[ 0 ];

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--exclude"
                  && argument_array.length >= 1 )
        {
            ExcludedFolderPathArray ~= argument_array[ 0 ];

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--filter"
                  && argument_array.length >= 1 )
        {
            IncludedFileNameFilterArray ~= argument_array[ 0 ];

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--ignore"
                  && argument_array.length >= 1 )
        {
            ExcludedFileNameFilterArray ~= argument_array[ 0 ];

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--print" )
        {
            PrintOptionIsEnabled = true;
        }
        else if ( option == "--confirm" )
        {
            ConfirmOptionIsEnabled = true;
        }
        else if ( option == "--preview" )
        {
            PreviewOptionIsEnabled = true;
        }
        else if ( option == "--precision"
                  && argument_array.length >= 1 )
        {
            millisecond_count = argument_array[ 0 ].to!long();

            MinimumModificationTimeOffset = msecs( -millisecond_count );
            MaximumModificationTimeOffset = msecs( millisecond_count );

            argument_array = argument_array[ 1 .. $ ];
        }
        else if ( option == "--sample"
                  && argument_array.length >= 1 )
        {
            SampleByteCount = argument_array[ 0 ].to!long() * 1024;

            if ( SampleByteCount < 0 )
            {
                SampleByteCount = 0;
            }

            argument_array = argument_array[ 1 .. $ ];
        }
    }
    
    if ( argument_array.length == 2 )
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
        writeln( "    --updated" );
        writeln( "    --changed" );
        writeln( "    --moved" );
        writeln( "    --removed" );
        writeln( "    --added" );
        writeln( "    --include SUBFOLDER/" );
        writeln( "    --exclude SUBFOLDER/" );
        writeln( "    --filter *.ext" );
        writeln( "    --ignore *.ext" );
        writeln( "    --print" );
        writeln( "    --confirm" );
        writeln( "    --preview" );
        writeln( "    --precision 1" );
        writeln( "    --sample 128" );
        writeln( "Examples :" );
        writeln( "    resync --changed --removed --added --exclude .git/ --print --confirm SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --changed --removed --added --preview SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --updated SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --moved SOURCE_FOLDER/ TARGET_FOLDER/" );

        Abort( "Invalid arguments : " ~ argument_array.to!string() );
    }
}

