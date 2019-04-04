package edu.cmu.cs.obsidian.client;

import org.json.JSONObject;
import org.json.JSONTokener;
import org.json.JSONWriter;

import java.util.ArrayList;
import java.util.Base64;
import java.util.StringJoiner;
import org.apache.commons.io.IOUtils;

/**
 * Created by mcoblenz on 4/3/17.
 */
public class ChaincodeClientConnectionManager {
    private final boolean printDebug;

    public ChaincodeClientConnectionManager(boolean printDebug) {
        this.printDebug = printDebug;
    }

    public byte[] doTransaction(String transactionName, ArrayList<byte[]> args, String receiverUUID, boolean returnsNonvoid)
            throws java.io.IOException,
                ChaincodeClientTransactionFailedException,
                ChaincodeClientTransactionBugException
    {
        ArrayList<String> cmdArgs = new ArrayList<String>();
        cmdArgs.add("../../../network-framework/invoke.sh");

        cmdArgs.add("-q");
        cmdArgs.add(transactionName);
        cmdArgs.add("__receiver");
        cmdArgs.add(receiverUUID);
        for (int i = 0; i < args.size(); i++) {
            byte[] bytes = args.get(i);
            String byteString = Base64.getEncoder().encodeToString(bytes);
            cmdArgs.add(byteString);
        }

        if (printDebug) {
            System.err.println("invocation parameters: " + cmdArgs);
        }

        ProcessBuilder pb = new ProcessBuilder(cmdArgs);
        pb.redirectError(ProcessBuilder.Redirect.INHERIT);
        Process process = pb.start();

        String output = IOUtils.toString(process.getInputStream(), java.nio.charset.StandardCharsets.UTF_8);
        try {
            process.waitFor();
        }
        catch (InterruptedException e) {
            System.err.println("Process interrupted: e");
        }

        return output.getBytes();
    }
}
