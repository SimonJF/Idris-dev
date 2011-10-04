{-# LANGUAGE MultiParamTypeClasses, FlexibleInstances #-}

module Core.CoreParser(parseTerm, parseFile, parseDef, pTerm, iName) where

import Core.TT

import Text.ParserCombinators.Parsec
import Text.ParserCombinators.Parsec.Expr
import Text.ParserCombinators.Parsec.Language
import qualified Text.ParserCombinators.Parsec.Token as PTok

import Debug.Trace

type TokenParser a = PTok.TokenParser a

lexer :: TokenParser ()
lexer  = PTok.makeTokenParser haskellDef

whiteSpace= PTok.whiteSpace lexer
lexeme    = PTok.lexeme lexer
symbol    = PTok.symbol lexer
natural   = PTok.natural lexer
parens    = PTok.parens lexer
semi      = PTok.semi lexer
comma     = PTok.comma lexer
identifier= PTok.identifier lexer
reserved  = PTok.reserved lexer
operator  = PTok.operator lexer
reservedOp= PTok.reservedOp lexer
lchar = lexeme.char

parseFile = parse pTestFile "(input)"
parseDef = parse pDef "(input)"
parseTerm = parse pTerm "(input)"

pTestFile :: Parser RProgram
pTestFile = do p <- many1 pDef ; eof
               return p

iName :: Parser Name
iName = identifier >>= (\n -> return (UN [n]))

pDef :: Parser (Name, RDef)
pDef = try (do x <- iName; lchar ':'; ty <- pTerm
               lchar '='
               tm <- pTerm
               lchar ';'
               return (x, RFunction (RawFun ty tm)))
       <|> do x <- iName; lchar ':'; ty <- pTerm; lchar ';'
              return (x, RConst ty)
       <|> do (x, d) <- pData; lchar ';'
              return (x, RData d)

app :: Parser (Raw -> Raw -> Raw)
app = do whiteSpace ; return RApp

arrow :: Parser (Raw -> Raw -> Raw)
arrow = do symbol "->" ; return $ \s t -> RBind (MN 0 "X") (Pi s) t

pTerm :: Parser Raw
pTerm = try (do chainl1 pNoApp app)
           <|> pNoApp

pNoApp :: Parser Raw
pNoApp = try (chainr1 pExp arrow)
           <|> pExp
pExp :: Parser Raw
pExp = do lchar '\\'; x <- iName; lchar ':'; ty <- pTerm
          symbol "=>";
          sc <- pTerm
          return (RBind x (Lam ty) sc)
       <|> try (do lchar '?'; x <- iName; lchar ':'; ty <- pTerm
                   lchar '.';
                   sc <- pTerm
                   return (RBind x (Hole ty) sc))
       <|> try (do lchar '('; 
                   x <- iName; lchar ':'; ty <- pTerm
                   lchar ')';
                   symbol "->";
                   sc <- pTerm
                   return (RBind x (Pi ty) sc))
       <|> try (do lchar '('; 
                   t <- pTerm
                   lchar ')'
                   return t)
       <|> try (do symbol "??";
                   x <- iName; lchar ':'; ty <- pTerm
                   lchar '=';
                   val <- pTerm
                   sc <- pTerm
                   return (RBind x (Guess ty val) sc))
       <|> try (do reserved "let"; 
                   x <- iName; lchar ':'; ty <- pTerm
                   lchar '=';
                   val <- pTerm
                   reserved "in";
                   sc <- pTerm
                   return (RBind x (Let ty val) sc))
       <|> try (do lchar '_'; 
                   x <- iName; lchar ':'; ty <- pTerm
                   lchar '.';
                   sc <- pTerm
                   return (RBind x (PVar ty) sc))
       <|> try (do reserved "Set"; i <- option 0 natural
                   return (RSet (fromInteger i)))
       <|> try (do x <- iName
                   return (Var x))

pData :: Parser (Name, RawDatatype)
pData = do reserved "data"; x <- iName; lchar ':'; ty <- pTerm; reserved "where"
           cs <- many pConstructor
           return (x, RDatatype x ty cs)

pConstructor :: Parser (Name, Raw)
pConstructor = do lchar '|'
                  c <- iName; lchar ':'; ty <- pTerm
                  return (c, ty)
