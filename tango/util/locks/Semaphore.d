/*******************************************************************************
  copyright:   Copyright (c) 2006 Juan Jose Comellas. All rights reserved
  license:     BSD style: $(LICENSE)
  author:      Juan Jose Comellas <juanjo@comellas.com.ar>
*******************************************************************************/

module tango.util.locks.Semaphore;

private import tango.util.locks.LockException;
private import tango.core.Type;
private import tango.sys.Common;
private import tango.text.convert.Integer;


version (Posix)
{
    private import tango.util.locks.Mutex;

    private import tango.stdc.posix.time;
    private import tango.stdc.posix.semaphore;
    private import tango.stdc.errno;


    /**
     * Wrapper for Dijkstra-style general semaphores that work only within
     * one process.
     */
    public class Semaphore
    {
        private sem_t _sem;

        /**
         * Initialize the semaphore, with initial value of <count>.
         */
        public this(int count)
        {
            int rc = sem_init(&_sem, 0, count);
            if (rc != 0)
            {
                checkError(__FILE__, __LINE__);
            }
        }

        /**
         * Free all the resources allocated by the semaphore.
         */
        public ~this()
        {
            int rc = sem_destroy(&_sem);
            if (rc != 0)
            {
                checkError(__FILE__, __LINE__);
            }
        }

        /**
         * Blocks the calling thread until the semaphore count is greater
         * than 0, at which point the count is atomically decremented.
         */
        public void acquire()
        {
            int rc = sem_wait(&_sem);
            if (rc != 0)
            {
                checkError(__FILE__, __LINE__);
            }
        }

        /**
         * Conditionally decrement the semaphore if count is greater than 0
         * (i.e. it won't block).
         *
         * Returns: true if we could acquire the semaphore; false on failure
         *          (i.e. we "fail" if someone else already had the lock).
         */
        public bool tryAcquire()
        {
            int rc = sem_trywait(&_sem);

            if (rc == 0)
            {
                return true;
            }
            else if (SysError.lastCode() == EAGAIN)
            {
                return false;
            }
            else
            {
                checkError(__FILE__, __LINE__);
                return false;
            }
        }

        version (linux)
        {
            /**
             * Conditionally decrement the semaphore if count is greater
             * than 0, waiting for the specified time.
             *
             * Returns: true if we could acquire the semaphore; false on failure
             *          (i.e. we "fail" if someone else already had the lock).
             */
            public bool tryAcquire(Interval timeout)
            {
                int rc;
                timespec ts;

                rc = sem_timedwait(&_sem, toTimespec(&ts, toAbsoluteTime(timeout)));

                if (rc == 0)
                {
                    return true;
                }
                else if (SysError.lastCode() == ETIMEDOUT)
                {
                    return false;
                }
                else
                {
                    checkError(__FILE__, __LINE__);
                    return false;
                }
            }
        }

        /**
         * Increment the semaphore by <count>, potentially unblocking waiting
         * threads.
         */
        public void release(uint count = 1)
        {
            for (uint i = 0; i < count; i++)
            {
                if (sem_post(&_sem) != 0)
                {
                    break;
                }
            }
        }

        /**
         * Check the value of errno against possible values and throw an 
         * exception with the description of the error.
         *
         * Params:
         * file         = name of the source file where the check is being
         *                made; you would normally use __FILE__ for this
         *                parameter.
         * line         = line number of the source file where this method
         *                was called; you would normally use __LINE__ for
         *                this parameter.
         *
         * Throws:
         * AlreadyLockedException when the semaphore has already been locked
         * by another thread (EBUSY, EAGAIN); DeadlockException when the
         * semaphore has already been locked by the calling thread (EDEADLK);
         * InvalidSemaphoreException when the semaphore has not been properly
         * initialized (EINVAL); SempahoreOwnerException when the calling
         * thread does not own the mutex (EPERM); LockException for any of
         * the other cases in which errno is not 0.
         */
        protected void checkError(char[] file, uint line)
        in
        {
            char[10] tmp;

            assert(SysError.lastCode() != 0, "checkError() was called with SysError.lastCode() == 0 on file " ~ 
                                             file ~ ":" ~ format(tmp, line));
        }
        body
        {
            int errorCode = SysError.lastCode();

            switch (errorCode)
            {
                case EBUSY:
                case EAGAIN:
                    throw new AlreadyLockedException(file, line);
                    // break;
                case EDEADLK:
                    throw new DeadlockException(file, line);
                    // break;
                case EINVAL:
                    throw new InvalidSemaphoreException(file, line);
                    // break;
                case EPERM:
                    throw new SemaphoreOwnerException(file, line);
                    // break;
                case EINTR:
                    throw new InterruptedSystemCallException(file, line);
                    // break;
                default:
                    char[10] tmp;

                    throw new LockException("Unknown semaphore error " ~ format(tmp, errorCode) ~
                                            ": " ~ SysError.lookup(errorCode), file, line);
                    // break;
            }
        }
    }
}
else version (Windows)
{
    /**
     * Wrapper for Dijkstra-style general semaphores that work only within
     * one process.
     */
    public class Semaphore
    {
        private HANDLE _sem;

        /**
         * Initialize the semaphore, with initial value of <count>.
         */
        public this(int count)
        {
            _sem = CreateSemaphoreA(null, cast(LONG) count, cast(LONG) int.max, null);
            if (_sem == cast(HANDLE) NULL)
            {
                checkError(__FILE__, __LINE__);
            }
        }

        /**
         * Free all the resources allocated by the semaphore.
         */
        ~this()
        {
            CloseHandle(_sem);
        }

        /**
         * Blocks the calling thread until the semaphore count is greater
         * than 0, at which point the count is atomically decremented.
         */
        public void acquire()
        {
            DWORD result = WaitForSingleObject(_sem, INFINITE);

            if (result != WAIT_OBJECT_0)
            {
                checkError(__FILE__, __LINE__);
            }
        }

        /**
         * Conditionally decrement the semaphore if count is greater than 0
         * (i.e. it won't block).
         *
         * Returns: true if we could acquire the semaphore; false on failure
         *          (i.e. we "fail" if someone else already had the lock).
         */
        public bool tryAcquire()
        {
            return tryAcquire(cast(Interval) 0);
        }

        /**
         * Conditionally decrement the semaphore if count is greater
         * than 0, waiting for the specified time.
         *
         * Returns: true if we could acquire the semaphore; false on failure
         *          (i.e. we "fail" if someone else already had the lock).
         */
        public bool tryAcquire(Interval timeout)
        {
            DWORD result = WaitForSingleObject(_sem,
                                               cast(DWORD) (timeout != Interval.max ?
                                                            cast(DWORD) (timeout * 1000.0) :
                                                            INFINITE));

            if (result == WAIT_OBJECT_0)
            {
                return true;
            }
            else if (result == WAIT_TIMEOUT)
            {
                return false;
            }
            else
            {
                checkError(__FILE__, __LINE__);
                return false;
            }
        }

        /**
         * Increment the semaphore by <count>, potentially unblocking waiting
         * threads.
         */
        public void release(int count = 1)
        {
            if (!ReleaseSemaphore(_sem, cast(LONG) count, null))
            {
                checkError(__FILE__, __LINE__);
            }
        }

        /**
         * Check the result from the GetLastError() Windows function and
         * throw an exception with the description of the error.
         *
         * Params:
         * file     = name of the source file where the check is being made; you
         *            would normally use __FILE__ for this parameter.
         * line     = line number of the source file where this method was called;
         *            you would normally use __LINE__ for this parameter.
         *
         * Throws:
         * AccessDeniedException when the caller does not have permissions to
         * use the mutex; LockException for any of the other cases in which
         * GetLastError() is not 0.
         */
        protected void checkError(char[] file, uint line)
        in
        {
            char[10] tmp;

            assert(SysError.lastCode() != 0, "checkError() was called with SysError.lastCode() == 0 on file " ~ 
                                             file ~ ":" ~ format(tmp, line));
        }
        body
        {
            uint errorCode = SysError.lastCode();

            switch (errorCode)
            {
                case ERROR_ACCESS_DENIED:
                    throw new AccessDeniedException(file, line);
                    // break;
                default:
                    char[10] tmp;

                    throw new LockException("Unknown semaphore error " ~ format(tmp, errorCode) ~
                                            ": " ~ SysError.lookup(errorCode), file, line);
                    // break;
            }
        }
    }
}
else
{
    static assert(false, "Semaphores are not supported on this platform");
}
