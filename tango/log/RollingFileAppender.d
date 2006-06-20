/*******************************************************************************

        copyright:      Copyright (c) 2004 Kris Bell. All rights reserved

        license:        BSD style: $(LICENSE)
      
        version:        Initial release: May 2004
        
        author:         Kris

*******************************************************************************/

module tango.log.RollingFileAppender;

version (Isolated){}
else
{
private import  tango.log.Appender,
                tango.log.FileAppender;

private import  tango.io.FilePath,
                tango.io.FileConst,
                tango.io.FileConduit,
                tango.io.protocol.DisplayWriter;

/*******************************************************************************

        Append log messages to a file set. 

*******************************************************************************/

public class RollingFileAppender : FileAppender
{
        private static uint     mask;
        private FilePath[]      paths;
        private int             index;
        private IBuffer         buffer;
        private ulong           maxSize,
                                fileSize;

        /***********************************************************************
                
                Get a unique fingerprint for this class

        ***********************************************************************/

        static this()
        {
                mask = nextMask();
        }

        /***********************************************************************
                
                Create a basic RollingFileAppender to a file-set with the 
                specified path.

        ***********************************************************************/

        this (FilePath p, int count, ulong maxSize)
        in {
           assert (count > 1 && count < 10);
           assert (p);
           }
        body
        {
                char[1] x;
                for (int i=0; i < count; ++i)
                    {
                    x[0] = '0' + i;

                    MutableFilePath clone = new MutableFilePath (p);
                    clone.setName (clone.getName ~ x);
                    paths ~= clone;
                    }

                this.maxSize = maxSize;
                index = -1;
                nextFile ();
        }

        /***********************************************************************
                
                Create a basic RollingFileAppender to a file-set with the 
                specified path, and with the given Layout

        ***********************************************************************/

        this (FilePath p, int count, ulong maxSize, Layout layout)
        {
                this (p, count, maxSize);
                setLayout (layout);
        }

        /***********************************************************************
                
                Return the fingerprint for this class

        ***********************************************************************/

        uint getMask ()
        {
                return mask;
        }

        /***********************************************************************
                
                Return the name of this class

        ***********************************************************************/

        char[] getName ()
        {
                return this.classinfo.name;
        }

        /***********************************************************************
                
                Append an event to the output.
                 
        ***********************************************************************/

        synchronized void append (Event event)
        {
                char[] msg;

                // file already full?
                if (fileSize >= maxSize)
                    nextFile ();

                // bump file size
                fileSize += FileConst.NewlineString.length;

                // writer log message and flush it
                Layout layout = getLayout;
                msg = layout.header (event);
                fileSize += msg.length;
                buffer.append (msg);

                msg = layout.content (event);
                fileSize += msg.length;
                buffer.append (msg);

                msg = layout.footer (event);
                fileSize += msg.length;
                buffer.append (msg);

                buffer.append(FileConst.NewlineString).flush();
        }

        /***********************************************************************
                
                Switch to the next file within the set

        ***********************************************************************/

        private void nextFile ()
        {
                // select next file in the set
                if (++index >= paths.length)
                    index = 0;
                
                // reset file size
                fileSize = 0;

                // close any existing conduit
                close ();

                // open file; get writer
                buffer = setConduit (new FileConduit (paths[index], FileConduit.WriteAppending));
        }
}
}
