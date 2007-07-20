import tango.io.FileConduit;
import tango.io.FileScan;
import tango.io.Stdout;
import tango.io.protocol.DisplayWriter;
import tango.sys.Process;
import tango.text.Util;
import Integer = tango.text.convert.Integer;


void main( char[][] args )
{
    scope(exit) Stdout.flush;

    auto    outf = new FileConduit( "tango.lsp", FileConduit.ReadWriteCreate );
    auto    link = new DisplayWriter( outf );
    auto    scan = new FileScan;
    char[]  path = "..\\tango";
    char[]  list = null;

    if( args.length > 1 )
        path = args[1] ~ "\\tango";

    link( "-c -n -p256\ntango.lib\n"c );
    foreach(file; scan( path, ".d" ).files )
    {
        if( filter( file ) )
            continue;
        char[] temp = objname( file );
        exec( "dmd -c -inline -release -O " ~
              "-of" ~ objname( file ) ~ " " ~
              file.toUtf8 );
        link( temp )( '\n' );
        list ~= " " ~ temp;
        delete temp;
    }
    link.flush;
    outf.close;
    exec( "lib @tango.lsp" );
    exec( "cmd /q /c del tango.lsp" ~ list );
}


bool filter( FilePath file )
{
    return containsPattern( file.folder, "posix"  ) ||
           containsPattern( file.folder, "linux"  ) ||
           containsPattern( file.folder, "darwin" ) ||
           containsPattern( file.name,   "Posix"  );
}


char[] objname( FilePath file )
{
    size_t pos = 0;
    char[] name = file.folder;
    foreach( elem; name )
    {
        if( elem == '.' || elem == '\\' )
        {
            ++pos; continue;
        }
        break;
    }
    return file.folder[pos .. $].dup.replace( '\\', '-' ) ~ file.name ~ ".obj";
}


void exec( char[] cmd, char[] workDir = null )
{
    exec( split( cmd, " " ), null, workDir );
}


void exec( char[][] cmd, char[] workDir = null )
{
    exec( cmd, null, workDir );
}


void exec( char[] cmd, char[][char[]] env, char[] workDir = null )
{
    exec( split( cmd, " " ), env, workDir );
}


void exec( char[][] cmd, char[][char[]] env, char[] workDir = null )
{
    scope auto    proc = new Process( cmd, env );
    if( workDir ) proc.workDir = workDir;

    foreach( str; cmd )
        Stdout( str )( ' ' );
    Stdout( '\n' );
    proc.execute();
    Stdout.conduit.copy( proc.stdout );
    Stdout.conduit.copy( proc.stderr );
    auto result = proc.wait();
    if( result.reason != Process.Result.Exit )
        throw new Exception( result.toUtf8() );
}
