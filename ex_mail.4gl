IMPORT util

DEFINE mail RECORD
    to      STRING,
    cc      STRING, 
    bcc,
    subject STRING,
    body    STRING
END RECORD
DEFINE cmd RECORD
    from    STRING,
    cmd     STRING,
    output  STRING
END RECORD

DEFINE smtp RECORD
    host STRING,
    port INTEGER,
    username STRING,
    password STRING
END RECORD
    

MAIN

DEFINE result STRING
DEFINE l_cmd STRING

DEFINE mc base.Channel
DEFINE res INTEGER
DEFINE tok base.StringTokenizer

    OPTIONS INPUT WRAP
  
    LET mail.to = "test_from@example.com"
    LET mail.cc = "test_cc@example.com"
    LET mail.bcc = "test_bcc@example.com"
    LET mail.subject = "Test Subject"
    LET mail.body = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."

    LET cmd.from = "test_from@example.com"
    LET cmd.cmd = "echo \"%6\" | mail -s %5 -c %3 -b %4 -f %2 %1"

    -- To test on SMTP set up a free account at smtp2go.com
    LET smtp.host = "mail.smtp2go.com"
    LET smtp.port = "2525"
    LET smtp.username = "reuben@4js.com.au"  -- replace with your account username
    # LET smtp.password = "password"         -- no password required if sent from my home office
    
    CALL ui.Interface.loadStyles("ex_mail")
    CLOSE WINDOW SCREEN
    OPEN WINDOW w WITH FORM "ex_mail"

    DISPLAY "<a href=\"null\">Link not set</a>" TO mailto

    INPUT BY NAME mail.*, cmd.*, smtp.* ATTRIBUTES(WITHOUT DEFAULTS=TRUE, UNBUFFERED)
        ON ACTION refresh
            DISPLAY SFMT("<a href=\"%1\">Click to send mail</click",mailto_url()) TO mailto
        ON ACTION launchurl1
            CALL ui.Interface.frontCall("standard","launchurl",mailto_url(), result)
        ON ACTION launchurl2
            CALL ui.Interface.frontCall("standard","launchurl",mailto_url(), result)

        ON ACTION cmd_send
            LET l_cmd = SFMT(cmd.cmd, cmd.from, mail.to, mail.cc, mail.bcc, mail.subject, mail.body)
            RUN l_cmd RETURNING result
            DISPLAY result TO output

        ON ACTION smtp_send
    
            LET mc = base.Channel.create()
            -- We use channel binary mode to avoid CR+LF translation on Windows.
            -- In text mode, each line would be terminated by \r\r\n on Windows.
            CALL mc.openClientSocket(smtp.host, smtp.port, "ub", 5)
            CALL readSmtpAnswer(mc) RETURNING res, result
            CALL smtpSend(mc, "HELO ok\r") RETURNING res, result
            CALL smtpSend(mc, SFMT("MAIL FROM: %1\r", smtp.username)) RETURNING res, result
            CALL smtpSend(mc, SFMT("RCPT TO: %1\r", mail.to)) RETURNING res, result
            CALL smtpSend(mc, "DATA\r") RETURNING res, result
            DISPLAY "Sending mail body:"
            CALL mc.writeLine(SFMT("Subject: %1\r", mail.subject))
            LET tok = base.StringTokenizer.create(mail.body,"\n")
            WHILE tok.hasMoreTokens()
                CALL mc.writeLine(SFMT("%1\r",tok.nextToken()))
            END WHILE
            CALL mc.writeLine(".\r")
            CALL readSmtpAnswer(mc) RETURNING res, result
            DISPLAY "  Result: ", res
            CALL smtpSend(mc, "QUIT\r") RETURNING res, result
            CALL mc.close()
            
        AFTER INPUT
            IF int_flag THEN
                EXIT INPUT
            END IF
    END INPUT
END MAIN


FUNCTION smtpSend(ch, command)
    DEFINE ch base.Channel
    DEFINE command, msg STRING
    DEFINE res INTEGER
    DISPLAY "Sending command: ", command
    CALL ch.writeLine(command)
    CALL readSmtpAnswer(ch) RETURNING res, msg
    DISPLAY "  Result: ", res
    RETURN res, msg
END FUNCTION

FUNCTION readSmtpAnswer(ch)
    DEFINE ch base.Channel
    DEFINE line, msg STRING
    DEFINE res INTEGER
    LET msg = ""
    WHILE TRUE
        LET line = ch.readLine()
        IF line IS NULL THEN
            RETURN -1, "COULD NOT READ SMTP ANSWER"
        END IF
        IF line MATCHES "[0-9][0-9][0-9] *" THEN
            IF msg.getLength() != 0 THEN
                LET msg=msg || "\n"
            END IF
            LET msg=msg.append(line.subString(4, line.getLength()))
            LET res = line.subString(1,3)
            RETURN res, msg
        END IF
        IF line MATCHES "[0-9][0-9][0-9]-*" THEN
            IF msg.getLength() != 0 THEN
                LET msg=msg || "\n"
            END IF
            LET msg=msg.append(line.subString(4, line.getLength()))
        END IF
    END WHILE
    RETURN 0, "NEVER GET HERE"
END FUNCTION


FUNCTION mailto_url()
    RETURN SFMT("mailto:%1?subject=%4&cc=%2&bcc=%3&body=%5", mail.to, mail.cc, mail.bcc, util.Strings.urlEncode(mail.subject),util.Strings.urlEncode(mail.body))
END FUNCTION