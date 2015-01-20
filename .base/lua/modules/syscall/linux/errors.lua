-- Linux error messages

return {
  PERM = "Operation not permitted",
  NOENT = "No such file or directory",
  SRCH = "No such process",
  INTR = "Interrupted system call",
  IO = "Input/output error",
  NXIO = "No such device or address",
  ["2BIG"] = "Argument list too long",
  NOEXEC = "Exec format error",
  BADF = "Bad file descriptor",
  CHILD = "No child processes",
  AGAIN = "Resource temporarily unavailable",
  NOMEM = "Cannot allocate memory",
  ACCES = "Permission denied",
  FAULT = "Bad address",
  NOTBLK = "Block device required",
  BUSY = "Device or resource busy",
  EXIST = "File exists",
  XDEV = "Invalid cross-device link",
  NODEV = "No such device",
  NOTDIR = "Not a directory",
  ISDIR = "Is a directory",
  INVAL = "Invalid argument",
  NFILE = "Too many open files in system",
  MFILE = "Too many open files",
  NOTTY = "Inappropriate ioctl for device",
  TXTBSY = "Text file busy",
  FBIG = "File too large",
  NOSPC = "No space left on device",
  SPIPE = "Illegal seek",
  ROFS = "Read-only file system",
  MLINK = "Too many links",
  PIPE = "Broken pipe",
  DOM = "Numerical argument out of domain",
  RANGE = "Numerical result out of range",
  DEADLK = "Resource deadlock avoided",
  NAMETOOLONG = "File name too long",
  NOLCK = "No locks available",
  NOSYS = "Function not implemented",
  NOTEMPTY = "Directory not empty",
  LOOP = "Too many levels of symbolic links",
  NOMSG = "No message of desired type",
  IDRM = "Identifier removed",
  CHRNG = "Channel number out of range",
  L2NSYNC = "Level 2 not synchronized",
  L3HLT = "Level 3 halted",
  L3RST = "Level 3 reset",
  LNRNG = "Link number out of range",
  UNATCH = "Protocol driver not attached",
  NOCSI = "No CSI structure available",
  L2HLT = "Level 2 halted",
  BADE = "Invalid exchange",
  BADR = "Invalid request descriptor",
  XFULL = "Exchange full",
  NOANO = "No anode",
  BADRQC = "Invalid request code",
  BADSLT = "Invalid slot",
  BFONT = "Bad font file format",
  NOSTR = "Device not a stream",
  NODATA = "No data available",
  TIME = "Timer expired",
  NOSR = "Out of streams resources",
  NONET = "Machine is not on the network",
  NOPKG = "Package not installed",
  REMOTE = "Object is remote",
  NOLINK = "Link has been severed",
  ADV = "Advertise error",
  SRMNT = "Srmount error",
  COMM = "Communication error on send",
  PROTO = "Protocol error",
  MULTIHOP = "Multihop attempted",
  DOTDOT = "RFS specific error",
  BADMSG = "Bad message",
  OVERFLOW = "Value too large for defined data type",
  NOTUNIQ = "Name not unique on network",
  BADFD = "File descriptor in bad state",
  REMCHG = "Remote address changed",
  LIBACC = "Can not access a needed shared library",
  LIBBAD = "Accessing a corrupted shared library",
  LIBSCN = ".lib section in a.out corrupted",
  LIBMAX = "Attempting to link in too many shared libraries",
  LIBEXEC = "Cannot exec a shared library directly",
  ILSEQ = "Invalid or incomplete multibyte or wide character",
  RESTART = "Interrupted system call should be restarted",
  STRPIPE = "Streams pipe error",
  USERS = "Too many users",
  NOTSOCK = "Socket operation on non-socket",
  DESTADDRREQ = "Destination address required",
  MSGSIZE = "Message too long",
  PROTOTYPE = "Protocol wrong type for socket",
  NOPROTOOPT = "Protocol not available",
  PROTONOSUPPORT = "Protocol not supported",
  SOCKTNOSUPPORT = "Socket type not supported",
  OPNOTSUPP = "Operation not supported",
  PFNOSUPPORT = "Protocol family not supported",
  AFNOSUPPORT = "Address family not supported by protocol",
  ADDRINUSE = "Address already in use",
  ADDRNOTAVAIL = "Cannot assign requested address",
  NETDOWN = "Network is down",
  NETUNREACH = "Network is unreachable",
  NETRESET = "Network dropped connection on reset",
  CONNABORTED = "Software caused connection abort",
  CONNRESET = "Connection reset by peer",
  NOBUFS = "No buffer space available",
  ISCONN = "Transport endpoint is already connected",
  NOTCONN = "Transport endpoint is not connected",
  SHUTDOWN = "Cannot send after transport endpoint shutdown",
  TOOMANYREFS = "Too many references: cannot splice",
  TIMEDOUT = "Connection timed out",
  CONNREFUSED = "Connection refused",
  HOSTDOWN = "Host is down",
  HOSTUNREACH = "No route to host",
  ALREADY = "Operation already in progress",
  INPROGRESS = "Operation now in progress",
  STALE = "Stale NFS file handle",
  UCLEAN = "Structure needs cleaning",
  NOTNAM = "Not a XENIX named type file",
  NAVAIL = "No XENIX semaphores available",
  ISNAM = "Is a named type file",
  REMOTEIO = "Remote I/O error",
  DQUOT = "Disk quota exceeded",
  NOMEDIUM = "No medium found",
  MEDIUMTYPE = "Wrong medium type",
  CANCELED = "Operation canceled",
  NOKEY = "Required key not available",
  KEYEXPIRED = "Key has expired",
  KEYREVOKED = "Key has been revoked",
  KEYREJECTED = "Key was rejected by service",
  OWNERDEAD = "Owner died",
  NOTRECOVERABLE = "State not recoverable",
  RFKILL = "Operation not possible due to RF-kill",
  -- only on some platforms
  DEADLOCK = "File locking deadlock error",
  INIT = "Reserved EINIT", -- what is correct message?
  REMDEV = "Remote device", -- what is correct message?
  HWPOISON = "Reserved EHWPOISON", -- what is correct message?
}
