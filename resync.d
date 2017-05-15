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
import core.time;
import std.conv : to;
import std.datetime : SysTime;
import std.digest.md : MD5;
import std.file : copy, dirEntries, exists, getTimes, mkdirRecurse, readText, remove, rename, setTimes, write, SpanMode;
import std.path : baseName, dirName;
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

    void Read(
        string folder_path
        )
    {
        FILE
            file;

        try
        {
            foreach ( folder_entry; dirEntries( folder_path, FileNameFilter, SpanMode.shallow ) )
            {
                if ( folder_entry.isFile()
                     && !folder_entry.isSymlink() )
                {
                    file = new FILE;
                    file.Path = folder_entry;
                    file.RelativePath = file.Path[ Path.length .. $ ];
                    file.RelativeFolderPath = GetFolderPath( file.RelativePath );
                    file.Name = file.Path.baseName();
                    file.ModificationTime = folder_entry.timeLastModified;
                    file.ByteCount = folder_entry.size();

                    FileArray ~= file;
                    FileMap[ file.RelativePath ] = file;
                }
            }

            foreach ( folder_entry; dirEntries( folder_path, "*", SpanMode.shallow ) )
            {
                if ( folder_entry.isDir()
                     && !folder_entry.isSymlink() )
                {
                    Read( folder_entry );
                }
            }
        }
        catch ( Error error )
        {
            Abort( "Can't read folder : " ~ folder_path );
        }
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
    FileNameFilter,
    SourceFolderPath,
    TargetFolderPath;
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
    try
    {
        if ( !folder_path.exists() )
        {
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
        SysTime
            access_time,
            modification_time;

        GetFolderPath( target_file_path ).CreateFolder();

        source_file_path.getTimes( access_time, modification_time );
        source_file_path.copy( target_file_path );
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

    SourceFolder.Read( SourceFolderPath );
    TargetFolder.Read( TargetFolderPath );

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

    FileNameFilter = "*";
    SampleByteCount = 128 * 1024;
    MinimumModificationTimeOffset = msecs( -1 );
    MaximumModificationTimeOffset = msecs( 1 );
    PrintOptionIsEnabled = false;
    ConfirmOptionIsEnabled = false;
    PreviewOptionIsEnabled = false;
    UpdatedOptionIsEnabled = false;
    ChangedOptionIsEnabled = false;
    MovedOptionIsEnabled = false;
    RemovedOptionIsEnabled = false;
    AddedOptionIsEnabled = false;

    while ( argument_array.length >= 1
            && argument_array[ 0 ].startsWith( "--" ) )
    {
        option = argument_array[ 0 ];

        argument_array = argument_array[ 1 .. $ ];
        
        if ( option == "--filter"
             && argument_array.length >= 1 )
        {
            FileNameFilter = argument_array[ 0 ];

            argument_array = argument_array[ 1 .. $ ];
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
        writeln( "    --filter *" );
        writeln( "    --precision 1" );
        writeln( "    --sample 128" );
        writeln( "    --print" );
        writeln( "    --confirm" );
        writeln( "    --preview" );
        writeln( "    --updated" );
        writeln( "    --changed" );
        writeln( "    --moved" );
        writeln( "    --removed" );
        writeln( "    --added" );
        writeln( "Examples :" );
        writeln( "    resync --changed --removed --added --print --confirm SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --changed --removed --added --preview SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --updated SOURCE_FOLDER/ TARGET_FOLDER/" );
        writeln( "    resync --moved SOURCE_FOLDER/ TARGET_FOLDER/" );

        Abort( "Invalid arguments" );
    }
}

