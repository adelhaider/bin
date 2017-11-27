import javax.xml.namespace.*
import net.sf.saxon.om.NamespaceResolver

class CCNamespaceContext implements NamespaceContext, NamespaceResolver {
    
    private nsContext = null
    private nsReverseContext = null
    
    public CCNamespaceContext(nsContext) {
        this.nsContext = nsContext
        this.nsReverseContext = [:]
        nsContext.each{ key, value ->
            nsReverseContext.put value, key
        }
    }

    public String getNamespaceURI(String prefix) {
        if (prefix == null) {
            throw new IllegalArgumentException("Null prefix");
        }
        def ns = nsContext.get(prefix)
        if (ns == null) {
            throw new IllegalArgumentException("Prefix ${prefix} not found");
        }
        //printf "getNamespaceURI(${prefix}) resolved to #${ns}#\n"
        return ns;
    }

    public String getPrefix(String uri) {
        if (uri == null) {
            throw new IllegalArgumentException("Null URI");
        }
        def prefix = nsReverseContext.get(uri)
        if (prefix == null) {
            throw new IllegalArgumentException("URI not found");
        }
        return prefix;
    }

    public Iterator getPrefixes(String uri) {
        return nsContext.keySet().iterator();
    }
    
    public String getURIForPrefix(String prefix, boolean useDefault) {
        return getNamespaceURI(prefix, false)
    }
    
    public Iterator<String> iteratePrefixes() {
        return getPrefixes();
    }
}