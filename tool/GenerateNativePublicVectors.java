// Public-address fixture generator only. No keys, node, wallet, sockets or signing.
import java.util.*;
import org.ergoplatform.*;
import sigma.ast.ErgoTree;
import sigma.data.*;
import scala.collection.JavaConverters;

class GenerateNativePublicVectors {
    public static void main(String[] args) {
        ErgoTree control = ErgoTree.fromHex("0008cd0279be667ef9dcbbac55a06295ce870b07029bfcdb2dce28d959f2815b16f81798");
        SigmaBoolean key = control.toSigmaBooleanOpt().get();
        for (int size : new int[]{8, 120}) {
            List<SigmaBoolean> keys = new ArrayList<>();
            for (int i = 0; i < size; i++) keys.add(key);
            ErgoTree tree = ErgoTree.fromSigmaBoolean(new CAND(JavaConverters.asScalaBufferConverter(keys).asScala().toSeq()));
            Pay2SAddress address = new Pay2SAddress(tree, tree.bytes(), new ErgoAddressEncoder((byte)48));
            System.out.println("native_long_p2s_" + size + "\tOK\t" + address.toString() + "\t" + tree.bytesHex());
        }
    }
}
